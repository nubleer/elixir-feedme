defmodule Feedme do
  alias Feedme.XmlNode
  alias Feedme.Parsers.RSS2
  alias Feedme.Parsers.Atom

  defmodule Image do
    defstruct title: nil,
              url: nil,
              link: nil,
              width: nil,
              height: nil,
              description: nil
  end

  defmodule Enclosure do
    defstruct url: nil,
              length: nil,
              type: nil
  end

  defmodule MetaData do
    defstruct title: nil,
              link: nil,
              description: nil,
              author: nil,
              language: nil,
              copyright: nil,
              publication_date: nil,
              last_build_date: nil,
              generator: nil,
              category: nil,
              rating: nil,
              docs: nil,
              cloud: nil,
              ttl: nil,
              managing_editor: nil,
              web_master: nil,
              skip_hours: [],
              skip_days: [],
              image: nil,
              itunes: nil
  end

  defmodule Entry do
    defstruct title: nil,
              link: nil,
              description: nil,
              author: nil,
              categories: [],
              comments: nil,
              enclosure: nil,
              guid: nil,
              publication_date: nil,
              source: nil,
              itunes: nil,
              chapters: []
  end

  defmodule Feed do
    defstruct meta: nil, 
              entries: nil
  end

  defmodule Itunes do
    defstruct author: nil,
              block: nil,
              category: nil,
              image: nil,
              duration: nil,
              explicit: nil,
              isClosedCaptioned: nil,
              order: nil,
              complete: nil,
              new_feed_url: nil,
              owner: nil,              
              subtitle: nil,
              summary: nil
  end

  defmodule Chapter do
    defstruct start: nil,
              title: nil,
              href: nil,
              image: nil
  end

  def parse(xml) do
    {:ok, XmlNode.from_string(xml)}
    |> detect_parser
    |> parse_document
  end

  defp parse_document({:ok, parser, document}) do
    {:ok, parser.parse(document)}
  end

  defp parse_document(other), do: other

  defp detect_parser({:ok, document}) do
    cond do
      RSS2.valid?(document) -> {:ok, RSS2, document}
      Atom.valid?(document) -> {:ok, Atom, document}
      true -> {:error, "Feed format not valid"}
    end
  end

  defp detect_parser(other), do: other
end
