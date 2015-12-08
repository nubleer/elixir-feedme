defmodule Feedme.Parsers.RSS2Stream do

  use GenServer
  use Timex

  alias Feedme.Feed
  alias Feedme.Entry
  alias Feedme.MetaData
  alias Feedme.Itunes
  alias Feedme.AtomLink
  alias Feedme.Psc
  alias Feedme.Image
  alias Feedme.Enclosure

  alias Timex.DateFormat
  


  defmodule State do
    defstruct stream: nil,
      pid: nil,
      error: false,
      parser_state: nil
  end

  defmodule ParserState do
    defstruct current_element: nil,
      feed: nil
  end

  ## Client API

  def parse(xmlstring) do
    {:ok, parser} = start_link(self())
    :opened = open(parser)
    :parsed = parse_it(parser, xmlstring)
    result = receive do
      {:ok, feed} -> {:ok, feed}
      {:error, reason} -> {:error, reason} 
    after 1_000 -> 
      {:error, :parser_timeout}
    end
    stop(parser)
    result
  end

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def open(parser) do
    GenServer.call(parser, :open)
  end

  def parse_it(parser, chunk) do
    GenServer.call(parser, {:parse, chunk})
  end

  def stop(parser) do
    GenServer.call(parser, :stop)
  end

  ## Server Callbacks

  def init(pid) do
    {:ok, %State{pid: pid}}
  end

  def handle_call(:open, _from, state) do
    stream = :fxml_stream.new(self())
    state = %State{ state | stream: stream}
    {:reply, :opened, state}
  end

  def handle_call({:parse, chunk}, _from, state) do
    stream = :fxml_stream.parse(state.stream, chunk)
    state = %State{ state | stream: stream}
    {:reply, :parsed, state}
  end

  def handle_call(:stop, _from, state) do
    :fxml_stream.close(state.stream)
    {:stop, :normal, :ok, state}
  end

  def handle_info({:"$gen_event", {:xmlstreamstart, root_name, attrs}}, state) do
    case state.error do
      true -> {:noreply, state}
      false ->
        IO.inspect "HIER #{root_name}"
        case root_name do
          "rss" ->
            state = %State{ state | parser_state: %ParserState{feed: %Feed{}}}
          _ ->
            state = %State{ state | error: true}
            send state.pid, {:error, :no_rss_root}
        end
        {:noreply, state}
    end
  end

  def handle_info({:"$gen_event", {:xmlstreamelement, e}}, state) do
    case state.error do
      true -> {:noreply, state}
      false ->
        parsed = pe(e)
        state = %State{ state | parser_state: %ParserState{feed: parsed} }
        {:noreply, state}
    end
  end

  def handle_info({:"$gen_event", {:xmlstreamend, root_name}}, state) do
    case state.error do
      true -> {:noreply, state}
      false ->
        IO.inspect "ENDE #{root_name}"
        send state.pid, {:ok, state.parser_state.feed}
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    #IO.inspect msg
    {:noreply, state}
  end




  # nochn versuch

  defp pcdata(list) do
    Enum.reduce list, "", fn(el, acc) -> 
      case el do
        {:xmlcdata, cdata} -> acc <> cdata
        _ -> acc
      end
    end
  end

  defp parse_datetime(text) do
    case text |> DateFormat.parse("{RFC1123}") do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp map_element(content, name) do
    content 
    |>Enum.filter(fn(e)-> match?({:xmlel, name, [], _}, e) end)
    |> Enum.map(fn(el) ->
      {:xmlel, _, _, cdatalist} = el
      Enum.map(cdatalist, fn({k, v}) -> 
        v 
      end) |> Enum.join
    end)
  end

  defp map_to_integer(content) do
    content 
    |> Enum.map(fn(e) -> String.to_integer(e) end)
  end

  defp image_element(content) do
    Enum.reduce content, %Image{}, fn(el, image) ->
      case el do
        {:xmlel, "title", _attr, content} -> %Image{image | title: pcdata(content)}
        {:xmlel, "url", _attr, content} -> %Image{image | url: pcdata(content)}
        {:xmlel, "link", _attr, content} -> %Image{image | link: pcdata(content)}
        {:xmlel, "width", _attr, content} -> %Image{image | width: (pcdata(content) |> String.to_integer)}
        {:xmlel, "height", _attr, content} -> %Image{image | height: (pcdata(content) |> String.to_integer)}
        _ -> image
      end
    end
  end

  # not very efficient, refactor! you braindead wreck!
  defp extract_attribute(content, attr, attribute_name) do
    Enum.reduce attr, nil, fn({k, v}, acc) ->
      case k do
        attribute_name -> v
        _ -> acc
      end
    end
  end

  defp itunes_owner_element(content) do
    Enum.reduce content, %{name: nil, email: nil}, fn(el, map) ->
      case el do
        {:xmlel, "itunes:name", _attr, content} -> %{map | name: pcdata(content)}
        {:xmlel, "itunes:email", _attr, content} -> %{map | email: pcdata(content)}
        _ -> map
      end
    end
  end

  defp itunes_element(content, name, attr, itunes) do
    case name do
      "itunes:author" -> %Itunes{ itunes | author: pcdata(content)}
      "itunes:block" -> %Itunes{ itunes | block: pcdata(content)}
      "itunes:category" -> %Itunes{ itunes | category: pcdata(content)}
      "itunes:image" -> %Itunes{ itunes | image: (content |> extract_attribute(attr, "href"))}
      "itunes:duration" -> %Itunes{ itunes | duration: pcdata(content)}
      "itunes:explicit" -> %Itunes{ itunes | explicit: pcdata(content)}
      "itunes:isClosedCaptioned" -> %Itunes{ itunes | isClosedCaptioned: pcdata(content)}
      "itunes:order" -> %Itunes{ itunes | order: pcdata(content)}
      "itunes:complete" -> %Itunes{ itunes | complete: pcdata(content)}
      "itunes:new_feed_url" -> %Itunes{ itunes | new_feed_url: pcdata(content)}

      "itunes:owner" -> %Itunes{ itunes | owner: (content |> itunes_owner_element)}

      "itunes:subtitle" -> %Itunes{ itunes | subtitle: pcdata(content)}
      "itunes:summary" -> %Itunes{ itunes | summary: pcdata(content)}
      _ -> itunes
    end
  end

  defp atom_link(content, attributes) do
    %AtomLink{
      rel: Access.get(attributes, "rel", nil),
      type: Access.get(attributes, "type", nil),
      href: Access.get(attributes, "href", nil),
      title: Access.get(attributes, "title", nil),
    }
  end

  defp psc_elements(content, attributes) do
    Enum.reduce content, [], fn(el, list) ->
      case el do
        {:xmlel, "psc:chapter", attr, content} -> [
            %Psc{
              start: Access.get(attributes, "rel", nil),
              title: Access.get(attributes, "title", nil),
              href: Access.get(attributes, "href", nil),
              image: Access.get(attributes, "image", nil)
            } | list]
        _ -> list
      end
    end 
    #|> Enum.reverse
  end

  defp parse_item(content, _attr) do
    Enum.reduce content, %Entry{itunes: %Itunes{}, enclosure: %Enclosure{} }, fn(el, entry) ->
      case el do
        {:xmlel, "title", _attr, content} -> %Entry{entry | title: pcdata(content)}
        {:xmlel, "link", _attr, content} -> %Entry{entry | link: pcdata(content)}
        {:xmlel, "description", _attr, content} -> %Entry{entry | description: pcdata(content)}
        {:xmlel, "author", _attr, content} -> %Entry{entry | author: pcdata(content)}
        {:xmlel, "guid", _attr, content} -> %Entry{entry | guid: pcdata(content)}

        {:xmlel, "categories", _attr, content} -> %Entry{entry | categories: pcdata(content)}
        #{:xmlel, "comments", _attr, content} -> %Entry{entry | comments: pcdata(content)}
        #{:xmlel, "enclosure", _attr, content} -> %Entry{entry | enclosure: pcdata(content)}
        {:xmlel, "pubDate", _attr, content} -> %Entry{entry | publication_date: pcdata(content)}
        {:xmlel, "source", _attr, content} -> %Entry{entry | source: pcdata(content)}
        {:xmlel, name, attr, content} when binary_part(name, 0, 7) == "itunes:" ->
          %Entry{entry | itunes: (content |> itunes_element(name, attr, entry.itunes)) }

        {:xmlel, "psc:chapters", attr, content} -> %Entry{entry | psc: (content |> psc_elements(attr)) }

        {:xmlel, "atom:link", attr, content} -> %Entry{entry | atom_links: [ atom_link(content, attr) | entry.atom_links] }

        _ -> entry
      end
    end
  end

  defp pe({:xmlel, "channel", attribs, content}) do
    Enum.reduce content, %Feed{ meta: %MetaData{itunes: %Itunes{}}}, fn(el, feed) ->
      case el do
        {:xmlel, "title", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | title: pcdata(content)} }
        {:xmlel, "link", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | link: pcdata(content)} }
        {:xmlel, "description", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | description: pcdata(content)} }
        {:xmlel, "author", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | author: pcdata(content)} }
        {:xmlel, "language", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | language: pcdata(content)} }
        {:xmlel, "copyright", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | copyright: pcdata(content)} }

        {:xmlel, "pubDate", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | publication_date: pcdata(content) |> parse_datetime } }
        {:xmlel, "lastBuildDate", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | last_build_date: pcdata(content) |> parse_datetime } }

        {:xmlel, "generator", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | generator: pcdata(content)} }
        {:xmlel, "category", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | category: pcdata(content)} }
        {:xmlel, "rating", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | rating: pcdata(content)} }
        {:xmlel, "docs", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | docs: pcdata(content)} }
        {:xmlel, "cloud", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | cloud: pcdata(content)} }
        {:xmlel, "ttl", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | ttl: pcdata(content)} }
        {:xmlel, "managing_editor", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | managing_editor: pcdata(content)} }
        {:xmlel, "web_master", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | web_master: pcdata(content)} }

        {:xmlel, "skipHours", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | skip_hours: (content |> map_element("hour") |> map_to_integer ) } }
        {:xmlel, "skipDays", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | skip_days: (content |> map_element("day") |> map_to_integer ) } }

        {:xmlel, "image", _attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | image: (content |> image_element) } }
        
        {:xmlel, name, attr, content} when binary_part(name, 0, 7) == "itunes:" ->
          %Feed{feed | meta: %MetaData{ feed.meta | itunes: (content |> itunes_element(name, attr, feed.meta.itunes)) } }

        {:xmlel, "atom:link", attr, content} -> %Feed{feed | meta: %MetaData{ feed.meta | atom_links: [ atom_link(content, attr) | feed.meta.atom_links] } }

        {:xmlel, "item", attr, content} -> %Feed{feed | entries: [ parse_item(content, attr) | feed.entries] }


        _ -> feed
      end
    end
  end

end