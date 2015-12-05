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
        IO.inspect pe(state.parser_state, e)
        # state = %State{ state | parser_state: parse_elements(state.parser_state, e) }
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

  defp pe(parser_state, {:xmlel, "channel", attribs, content}) do
    meta = Enum.reduce content, %MetaData{}, fn(el, meta) ->
      case el do
        {:xmlel, "title", _attr, content} -> %MetaData{meta | title: pcdata(content)}
        {:xmlel, "link", _attr, content} -> %MetaData{meta | link: pcdata(content)}
        {:xmlel, "description", _attr, content} -> %MetaData{meta | description: pcdata(content)}
        {:xmlel, "author", _attr, content} -> %MetaData{meta | author: pcdata(content)}
        {:xmlel, "language", _attr, content} -> %MetaData{meta | language: pcdata(content)}
        {:xmlel, "copyright", _attr, content} -> %MetaData{meta | copyright: pcdata(content)}

        {:xmlel, "pubDate", _attr, content} -> %MetaData{meta | publication_date: pcdata(content) |> parse_datetime }
        {:xmlel, "lastBuildDate", _attr, content} -> %MetaData{meta | last_build_date: pcdata(content) |> parse_datetime }

        {:xmlel, "skipHours", _attr, content} -> %MetaData{meta | skip_hours: (content |> map_element("hour") |> map_to_integer ) }
        {:xmlel, "skipDays", _attr, content} -> %MetaData{meta | skip_days: (content |> map_element("day") |> map_to_integer ) }

        _ -> meta
      end
    end
    meta
  end




  # parse events

  defp parse_chardata(acc, []) do
    {acc, []}
  end
  defp parse_chardata(acc, {:xmlcdata, cdata}) do
    acc = acc <> cdata
    {acc, []}
  end
  defp parse_chardata(acc, [{:xmlcdata, cdata} | rest]) do
    acc = acc <> cdata
    parse_chardata(acc, rest)
  end
  defp parse_chardata(acc, rest) do
    {acc, rest}
  end

  defp parse_elements(parser_state, elements) when is_list(elements) do
    # IO.inspect "got a list"
    Enum.reduce elements, parser_state, fn(el, parser_state) -> 
      parse_elements(parser_state, el) 
    end
  end
  defp parse_elements(parser_state, {:xmlel, name, attribs, rest}) do
    #  IO.inspect "got el #{name}"
    # if parser_state.feed.meta do
    #   IO.inspect "--> #{parser_state.feed.meta.title}" 
    # end
    parser_state = case parser_state.current_element do
      nil ->
        case name do
          "channel" -> 
            %ParserState{ parser_state | 
              current_element: :channel, 
              feed: %Feed{ meta: %MetaData{} }
            }
          _ -> parser_state
        end
      :channel ->
        case name do
          "item" ->
            %ParserState{ parser_state | 
              current_element: :item, 
              feed: %Feed{ parser_state.feed | 
                entries: [%Entry{} | parser_state.feed.entries]
              }
            }
          "title" -> 
            # IO.inspect name
            {chardata, rest} = parse_chardata("", rest)
            %ParserState{ parser_state | 
              feed: %Feed{ parser_state.feed |
                meta: %MetaData{ parser_state.feed.meta | 
                  title: chardata
                } 
              } 
            }
          _ ->
            parser_state
        end
      :item ->
        case name do
          "item" ->
            %ParserState{ parser_state | 
              current_element: :item, 
              feed: %Feed{ parser_state.feed | 
                entries: [%Entry{} | parser_state.feed.entries]
              }
            }
          # "title" -> 
          #   # IO.inspect name
          #   {chardata, rest} = parse_chardata("", rest)
          #   %ParserState{ parser_state | 
          #     feed: %Feed{ parser_state.feed |
          #       meta: %MetaData{ parser_state.feed.meta | 
          #         title: chardata
          #       } 
          #     } 
          #   }
          _ ->
            parser_state
        end
      _ -> parser_state
    end

    # if name == "title" do
    #   IO.inspect "got el #{name} #{inspect attribs}"
    #   {chardata, rest} = parse_chardata("", rest)
    #   IO.inspect " --> #{chardata}"
    # end
    #parser_state = ...
    parse_elements(parser_state, rest)
  end
  defp parse_elements(parser_state, {:xmlel, name, attribs}) do
    IO.inspect "got last el #{name} #{attribs}"
    # parser_state = ...
    parser_state
  end
  defp parse_elements(parser_state, {:xmlcdata, cdata}) do
    # if String.strip(cdata) != "" do
    #   # IO.inspect " got data #{String.strip(cdata) |> String.slice(0, 100)}"
    #   # parser_state = ...
    # end
    parser_state
  end

end