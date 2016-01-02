defmodule Feedme.Parsers.RSS2Stream do

  # use GenServer
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

  def parse(xmlstring) do
    parsed_xml_result = :fxml_stream.parse_element(xmlstring)
    case parsed_xml_result do
      {:error, reason} -> {:error, reason}
      {:xmlel, "rss", _, content} -> do_parse(content)
      _ -> {:error, :no_rss_root}
    end
  end

  def valid?(xmlstring) do
    parsed_xml_result = :fxml_stream.parse_element(xmlstring)
    case parsed_xml_result do
      {:error, _} -> false
      {:xmlel, "rss", _, content} -> 
        channel = Enum.find content, fn(e) ->
          match? {:xmlel, "channel", _, _}, e 
        end
        case channel do
          nil -> false
          _ -> true
        end
      _ -> false
    end
  end

  defp pcdata(list) do
    list 
    |> Enum.reduce("", (fn(el, acc) -> 
      case el do
        {:xmlcdata, cdata} -> acc <> String.strip(cdata)
        _ -> acc
      end
    end))
  end

  def parse_datetime(text) do
    case text |> DateFormat.parse("{RFC1123}") do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp attr_get(attr, key, default \\ nil) do
    case :lists.keyfind(key, 1, attr) do
      {^key, value} -> value
      false -> default
    end
  end

  defp map_element(content, name) do
    content 
    |>Enum.filter(fn(e)-> match?({:xmlel, ^name, [], _}, e) end)
    |> Enum.map(fn(el) ->
      {:xmlel, _, _, cdatalist} = el
      Enum.map(cdatalist, fn({_k, v}) -> 
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
        {:xmlel, "description", _attr, content} -> %Image{image | description: pcdata(content)}
        {:xmlel, "url", _attr, content} -> %Image{image | url: pcdata(content)}
        {:xmlel, "link", _attr, content} -> %Image{image | link: pcdata(content)}
        {:xmlel, "width", _attr, content} -> %Image{image | width: (pcdata(content) |> String.to_integer)}
        {:xmlel, "height", _attr, content} -> %Image{image | height: (pcdata(content) |> String.to_integer)}
        _ -> image
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
      "itunes:block" -> %Itunes{ itunes | block: pcdata(content) == "yes"}
      "itunes:category" -> %Itunes{ itunes | category: attr_get(attr, "text")}
      "itunes:image" -> %Itunes{ itunes | image: attr_get(attr, "href")}
      "itunes:duration" -> %Itunes{ itunes | duration: pcdata(content)}
      "itunes:explicit" -> %Itunes{ itunes | explicit: pcdata(content) == "yes"}
      "itunes:isClosedCaptioned" -> %Itunes{ itunes | is_closed_captioned: pcdata(content) == "yes" }
      "itunes:order" -> %Itunes{ itunes | order: pcdata(content)}
      "itunes:complete" -> %Itunes{ itunes | complete: pcdata(content) == "yes"}
      "itunes:new_feed_url" -> %Itunes{ itunes | new_feed_url: pcdata(content)}
      "itunes:owner" -> %Itunes{ itunes | owner: (content |> itunes_owner_element)}
      "itunes:subtitle" -> %Itunes{ itunes | subtitle: pcdata(content)}
      "itunes:summary" -> %Itunes{ itunes | summary: pcdata(content)}
      _ -> itunes
    end
  end

  defp enclosure_content(attr) do
    %Enclosure{
      url: attr_get(attr, "url"),
      length: attr_get(attr, "length"),
      type: attr_get(attr, "type")
    }

    # Enum.reduce content, %Enclosure{}, fn(el, encl) ->
    #   case el do
    #     {:xmlel, "url", _attr, content} -> %Enclosure{encl | url: pcdata(content)}
    #     {:xmlel, "length", _attr, content} -> %Enclosure{encl | length: pcdata(content)}
    #     {:xmlel, "type", _attr, content} -> %Enclosure{encl | type: pcdata(content)}
    #     _ -> encl
    #   end
    # end
  end

  defp atom_link(_content, attributes) do
    %AtomLink{
      rel: attr_get(attributes, "rel", nil),
      type: attr_get(attributes, "type", nil),
      href: attr_get(attributes, "href", nil),
      title: attr_get(attributes, "title", nil),
    }
  end

  defp psc_elements(content, _attributes) do
    Enum.reduce(content, [], fn(el, list) ->
      case el do
        {:xmlel, "psc:chapter", attributes, _content} -> [
            %Psc{
              start: attr_get(attributes, "start", nil),
              title: attr_get(attributes, "title", nil),
              href: attr_get(attributes, "href", nil),
              image: attr_get(attributes, "image", nil)
            } | list]
        _ -> list
      end
    end)
    |> Enum.reverse
  end

  defp parse_item(content, _attr) do
    entry = Enum.reduce content, %Entry{itunes: %Itunes{}, enclosure: nil }, fn(el, entry) ->
      case el do
        {:xmlel, "title", _attr, content} -> %Entry{entry | title: pcdata(content)}
        {:xmlel, "link", _attr, content} -> %Entry{entry | link: pcdata(content)}
        {:xmlel, "description", _attr, content} -> %Entry{entry | description: pcdata(content)}
        {:xmlel, "author", _attr, content} -> %Entry{entry | author: pcdata(content)}
        {:xmlel, "guid", _attr, content} -> %Entry{entry | guid: pcdata(content)}

        {:xmlel, "category", _attr, content} -> %Entry{entry | categories: [ pcdata(content) | entry.categories] }
        {:xmlel, "comments", _attr, content} -> %Entry{entry | comments: pcdata(content)}
        {:xmlel, "enclosure", attr, _content} -> 
          %Entry{entry | enclosure: (attr |> enclosure_content) }
        {:xmlel, "pubDate", _attr, content} -> %Entry{entry | publication_date: pcdata(content) |> parse_datetime}
        {:xmlel, "source", _attr, content} -> %Entry{entry | source: pcdata(content)}
        {:xmlel, name, attr, content} when binary_part(name, 0, 7) == "itunes:" ->
          %Entry{entry | itunes: (content |> itunes_element(name, attr, entry.itunes)) }

        {:xmlel, "psc:chapters", attr, content} -> %Entry{entry | psc: (content |> psc_elements(attr)) }

        {:xmlel, "atom:link", attr, content} -> %Entry{entry | atom_links: [ atom_link(content, attr) | entry.atom_links] }

        _ -> entry
      end
    end
    %Entry{entry | atom_links: Enum.reverse(entry.atom_links) }
  end

  defp do_parse({:xmlel, "channel", _attribs, content}) do
    result = Enum.reduce content, %Feed{ meta: %MetaData{itunes: %Itunes{}}}, fn(el, feed) ->
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
    result = %Feed{result | entries: Enum.reverse(result.entries), meta: %MetaData{result.meta | atom_links: Enum.reverse(result.meta.atom_links) }}
    {:ok, result}
  end

  defp do_parse(content) do
    channel = Enum.find content, fn(e) ->
      match? {:xmlel, "channel", _, _}, e 
    end
    case channel do
      nil -> {:error, :no_channel_element}
      _ -> do_parse(channel)
    end
  end

end