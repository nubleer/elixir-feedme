defmodule Feedme do

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
              itunes: nil,
              atom_links: []
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
              psc: [],
              atom_links: []
  end

  defmodule Feed do
    defstruct meta: nil, 
              entries: []
  end

  defmodule Itunes do
    defstruct author: nil,
              block: nil,
              category: nil,
              image: nil,
              duration: nil,
              explicit: false,
              is_closed_captioned: false,
              order: nil,
              complete: false,
              new_feed_url: nil,
              owner: nil,              
              subtitle: nil,
              summary: nil
  end

  defmodule Psc do
    defstruct start: nil,
              title: nil,
              href: nil,
              image: nil
  end

  defmodule AtomLink do
    defstruct rel: nil,
              type: nil,
              href: nil,
              title: nil
  end

  defp reencode(xml) do
    result = Porcelain.exec("xmllint", ["--encode", "utf-8", "-"], in: xml, out: :string)
    IO.inspect result
    xml
  end

  def parse(xml) do
    case Feedme.Parsers.RSS2Stream.parse xml do
      {:error, {4, _}} -> xml |> reencode |> Feedme.Parsers.RSS2Stream.parse
      ok -> ok
    end
  end

end
