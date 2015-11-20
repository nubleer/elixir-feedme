defmodule Feedme.Test.Parsers.RSS2 do
  use ExUnit.Case
  
  alias Feedme.XmlNode
  alias Feedme.Parsers.RSS2

  setup do
    sample1 = XmlNode.from_file("test/fixtures/rss2/sample1.xml")
    sample2 = XmlNode.from_file("test/fixtures/rss2/sample2.xml")
    sample3 = XmlNode.from_file("test/fixtures/rss2/cre.xml")
    big_sample = XmlNode.from_file("test/fixtures/rss2/bigsample.xml")

    {:ok, [sample1: sample1, sample2: sample2, sample3: sample3, big_sample: big_sample]}
  end

  test "valid?", %{sample1: sample1, sample2: sample2, sample3: sample3} do
    wrong_doc = XmlNode.from_file("test/fixtures/wrong.xml")

    assert RSS2.valid?(sample1) == true
    assert RSS2.valid?(sample2) == true
    assert RSS2.valid?(sample3) == true
    assert RSS2.valid?(wrong_doc) == false
  end

  test "parse_meta", %{sample1: sample1, sample2: sample2, big_sample: big_sample} do
    meta = RSS2.parse_meta(sample1)
    assert meta == %Feedme.MetaData{
      title: "W3Schools Home Page",
      link: "http://www.w3schools.com",
      description: "Free web building tutorials",
      skip_hours: [1,2],
      skip_days: [1,2],
      image: %Feedme.Image{
        title: "Test Image",
        description: "test image...",
        url: "http://localhost/image"
      },
      last_build_date: %Timex.DateTime{
        calendar: :gregorian, day: 16,
        hour: 9, minute: 54, month: 8, ms: 0, second: 5,
        timezone: %Timex.TimezoneInfo{
          abbreviation: "UTC", from: :min,
          full_name: "UTC",
          offset_std: 0,
          offset_utc: 0,
          until: :max},
        year: 2015},
      publication_date: %Timex.DateTime{
        calendar: :gregorian,
        day: 15,
        hour: 9, minute: 54, month: 8, ms: 0, second: 5,
        timezone: %Timex.TimezoneInfo{
          abbreviation: "UTC",
          from: :min,
          full_name: "UTC",
          offset_std: 0,
          offset_utc: 0,
          until: :max
        },
        year: 2015
      },
      itunes: %Feedme.Itunes{
        author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil,
        image: nil, isClosedCaptioned: nil, new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
      }
    }

    meta = RSS2.parse_meta(sample2)
    assert meta == %Feedme.MetaData{
      link: "http://www.w3schools.com",
      itunes: %Feedme.Itunes{
        author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil,
        image: nil, isClosedCaptioned: nil, new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
      }
    }

    meta = RSS2.parse_meta(big_sample)
    assert meta == %Feedme.MetaData{
      description: "software is fun",
      link: "http://blog.drewolson.org/",
      title: "collect {thoughts}",
      ttl: "60",
      generator: "Ghost 0.6",
      last_build_date: %Timex.DateTime{
        calendar: :gregorian, 
        day: 28,
        hour: 18, minute: 56, month: 8, ms: 0, second: 0,
        timezone: %Timex.TimezoneInfo{
          abbreviation: "UTC", from: :min,
          full_name: "UTC", offset_std: 0, offset_utc: 0, until: :max
        },
        year: 2015
      },
      itunes: %Feedme.Itunes{
        author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil,
        image: nil, isClosedCaptioned: nil, new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
      },
      atom_links: [%Feedme.AtomLink{href: "http://blog.drewolson.org/rss/", rel: "self", title: nil, type: "application/rss+xml"}]
    }
  end

  test "parse_meta with atom links", %{sample3: sample3} do
    meta = RSS2.parse_meta(sample3)
    assert length(meta.atom_links) == 9
    [link | rest ] = meta.atom_links
    assert link.title =="CRE: Technik, Kultur, Gesellschaft (MPEG-4 AAC Audio)"
    assert link.rel == "self"
    assert link.href == "http://feeds.metaebene.me/cre/m4a"
    [link | _ ] = rest
    assert link.title =="CRE: Technik, Kultur, Gesellschaft (MP3 Audio)"
    assert link.rel == "alternate"
    assert link.href == "http://cre.fm/feed/mp3"
  end

  test "parse podast feed meta including itunes namespaced elements", %{sample3: sample3} do
    meta = RSS2.parse_meta(sample3)
    assert meta == %Feedme.MetaData{
      author: nil, category: nil, cloud: nil, copyright: nil,
      description: "Der Interview-Podcast mit Tim Pritlove", docs: nil, generator: "Podlove Podcast Publisher v2.3.3",
      image: %Feedme.Image{description: nil, height: nil, link: "http://cre.fm",
        title: "CRE: Technik, Kultur, Gesellschaft",
        url: "http://cre.fm/wp-content/cache/podlove/f9/f9fa0c2498fe20a0f85d4928e8423e/cre-technik-kultur-gesellschaft_original.jpg",
        width: nil
      },
      itunes: %Feedme.Itunes{
        author: "Metaebene Personal Media - Tim Pritlove", block: "no", category: nil,
       complete: nil, duration: nil, explicit: "no", image: nil, isClosedCaptioned: nil, new_feed_url: nil, order: nil,
       owner: nil, subtitle: "Der Interview-Podcast mit Tim Pritlove",
       summary: "Intensive und ausführliche Gespräche über Themen aus Technik, Kultur und Gesellschaft, das ist CRE. Interessante Gesprächspartner stehen Rede und Antwort zu Fragen, die man normalerweise selten gestellt bekommt. CRE möchte  aufklären, weiterbilden und unterhalten."
      },
      language: "de-DE",
      last_build_date: %Timex.DateTime{
        calendar: :gregorian, day: 12, hour: 22, minute: 47, month: 11, ms: 0,
        second: 30,
        timezone: %Timex.TimezoneInfo{
          abbreviation: "UTC", from: :min, full_name: "UTC", offset_std: 0, offset_utc: 0, until: :max
        }, 
        year: 2015
      }, 
      link: "http://cre.fm", managing_editor: nil, publication_date: nil, rating: nil,
      skip_days: [], skip_hours: [], title: "CRE: Technik, Kultur, Gesellschaft", ttl: nil, web_master: nil,
      atom_links: [%Feedme.AtomLink{href: "http://feeds.metaebene.me/cre/m4a", rel: "self",
        title: "CRE: Technik, Kultur, Gesellschaft (MPEG-4 AAC Audio)", type: "application/rss+xml"},
        %Feedme.AtomLink{href: "http://cre.fm/feed/mp3", rel: "alternate", title: "CRE: Technik, Kultur, Gesellschaft (MP3 Audio)",
        type: "application/rss+xml"},
        %Feedme.AtomLink{href: "http://cre.fm/feed/oga", rel: "alternate", title: "CRE: Technik, Kultur, Gesellschaft (Ogg Vorbis Audio)",
        type: "application/rss+xml"},
        %Feedme.AtomLink{href: "http://cre.fm/feed/opus", rel: "alternate", title: "CRE: Technik, Kultur, Gesellschaft (Ogg Opus Audio)",
        type: "application/rss+xml"}, %Feedme.AtomLink{href: "http://cre.fm/feed/m4a?paged=2", rel: "next", title: nil, type: nil},
        %Feedme.AtomLink{href: "http://cre.fm/feed/m4a", rel: "first", title: nil, type: nil},
        %Feedme.AtomLink{href: "http://cre.fm/feed/m4a?paged=4", rel: "last", title: nil, type: nil},
        %Feedme.AtomLink{href: "http://metaebene.superfeedr.com", rel: "hub", title: nil, type: nil},
        %Feedme.AtomLink{href: "https://flattr.com/submit/auto?user_id=timpritlove&language=de_DE&url=http%3A%2F%2Fcre.fm&title=CRE%3A+Technik%2C+Kultur%2C+Gesellschaft&description=Der+Interview-Podcast+mit+Tim+Pritlove",
        rel: "payment", title: "Flattr this!", type: "text/html"}
      ]
    }
  end

  test "parse_entry", %{big_sample: big_sample} do
    entry = XmlNode.first(big_sample, "/rss/channel/item")
            |> RSS2.parse_entry

    assert entry == %Feedme.Entry{
      author: nil,
      categories: [ "elixir" ],
      comments: nil,
      description: "<p>I previously <a href=\"http://blog.drewolson.org/the-value-of-explicitness/\">wrote</a> about explicitness in Elixir. One of my favorite ways the language embraces explicitness is in its distinction between eager and lazy operations on collections. Any time you use the <code>Enum</code> module, you're performing an eager operation. Your collection will be transformed/mapped/enumerated immediately. When you use</p>",
      enclosure: nil,
      guid: "9b68a5a7-4ab0-420e-8105-0462357fa1f1",
      itunes: %Feedme.Itunes{
        author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil, image: nil, isClosedCaptioned: nil,
        new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
      },
      link: "http://blog.drewolson.org/elixir-streams/",
      enclosure: %Feedme.Enclosure{
        url: "http://www.tutorialspoint.com/mp3s/tutorial.mp3",
        length: "12216320",
        type: "audio/mpeg"
      },
      publication_date: %Timex.DateTime{
        calendar: :gregorian,
        day: 8,
        hour: 13,
        minute: 43,
        month: 6,
        ms: 0,
        second: 5,
        timezone: %Timex.TimezoneInfo{
          abbreviation: "UTC",
          from: :min,
          full_name: "UTC",
          offset_std: 0,
          offset_utc: 0,
          until: :max
        },
        year: 2015
      },
      source: nil,
      title: "Elixir Streams"
    }
  end

  test "parse podast feed entries with itunes and podlove simple chapter (psc)", %{sample3: sample3} do
    entries = RSS2.parse_entries(sample3)
    assert entries
    assert length(entries) == 60
    entry = hd(entries)
    assert entry == %Feedme.Entry{author: nil, categories: [], comments: nil,
      description: "Der einst von Linus Torvalds geschaffene Betriebssystemkernel Linux ist eine freie Reimplementierung der UNIX Betriebssystemfamilie und hat sich in den letzten 20 Jahren sehr eigenständig entwickelt. Der Rest des Systems, das Userland, hat sich aber noch sehr stark an der klassischen Struktur von UNIX orientiert. Mit der Initiative systemd hat sich dies geändert und es entsteht eine sehr eigenständige Definition einer Linux-Systemebene, die sich zwischen Kernel und Anwendungen entfaltet und dort die Regeln der Installation und Systemadministration neu definiert.\n\nIch spreche mit dem Initiator des Projekts, Lennart Poettering, der schon vorher verschiedene Subsysteme zur Linux-Landschaft beigetragen hat über die Motivation und Struktur des Projekts, den aktuellen und zukünftigen Möglichkeiten der Software und welche kulturellen Auswirkungen der Einzug einer neuen Abstraktionsebene mit sich bringt.",
      enclosure: %Feedme.Enclosure{length: "65230396", type: "audio/mp4",
      url: "http://tracking.feedpress.it/link/13440/2008525/cre209-das-linux-system.m4a"}, guid: "podlove-2015-11-09t23:06:21+00:00-4501b131b3a9b1a",
      itunes: %Feedme.Itunes{author: "Metaebene Personal Media - Tim Pritlove", block: nil, category: nil, complete: nil, duration: "02:50:21",
      explicit: nil, image: nil, isClosedCaptioned: nil, new_feed_url: nil, order: nil, owner: nil,
      subtitle: "systemd leitet die neue Generation der Linux Systemarchitektur ein",
      summary: "Der einst von Linus Torvalds geschaffene Betriebssystemkernel Linux ist eine freie Reimplementierung der UNIX Betriebssystemfamilie und hat sich in den letzten 20 Jahren sehr eigenständig entwickelt. Der Rest des Systems, das Userland, hat sich aber noch sehr stark an der klassischen Struktur von UNIX orientiert. Mit der Initiative systemd hat sich dies geändert und es entsteht eine sehr eigenständige Definition einer Linux-Systemebene, die sich zwischen Kernel und Anwendungen entfaltet und dort die Regeln der Installation und Systemadministration neu definiert.\n\nIch spreche mit dem Initiator des Projekts, Lennart Poettering, der schon vorher verschiedene Subsysteme zur Linux-Landschaft beigetragen hat über die Motivation und Struktur des Projekts, den aktuellen und zukünftigen Möglichkeiten der Software und welche kulturellen Auswirkungen der Einzug einer neuen Abstraktionsebene mit sich bringt."},
      link: "http://cre.fm/cre209-das-linux-system",
      publication_date: %Timex.DateTime{calendar: :gregorian, day: 10, hour: 1, minute: 15, month: 11, ms: 0, second: 50,
      timezone: %Timex.TimezoneInfo{abbreviation: "UTC", from: :min, full_name: "UTC", offset_std: 0, offset_utc: 0, until: :max}, year: 2015},
      source: nil, title: "CRE209 Das Linux System",
      psc: [
        %Feedme.Psc{href: nil, image: nil, start: "00:00:00.000", title: "Intro"},
        %Feedme.Psc{href: nil, image: nil, start: "00:01:42.024", title: "Begrüßung"},
        %Feedme.Psc{href: nil, image: nil, start: "00:03:03.037", title: "Hacken als Grundeinstellung"},
        %Feedme.Psc{href: nil, image: nil, start: "00:06:09.589", title: "Persönlicher Werdegang"},
        %Feedme.Psc{href: nil, image: nil, start: "00:17:16.981", title: "PulseAudio"},
        %Feedme.Psc{href: nil, image: nil, start: "00:30:21.917", title: "Avahi"},
        %Feedme.Psc{href: nil, image: nil, start: "00:38:24.502", title: "Elitismus und Geheimwissen"},
        %Feedme.Psc{href: nil, image: nil, start: "00:51:38.717", title: "systemd : Beweggründe zur Entwicklung"},
        %Feedme.Psc{href: nil, image: nil, start: "01:25:27.304", title: "systemd: Vorbilder und alte Zöpfe"},
        %Feedme.Psc{href: nil, image: nil, start: "01:48:18.600", title: "systemd Entwickler"},
        %Feedme.Psc{href: nil, image: nil, start: "01:50:23.048", title: "UEFI Booting und Secure Boot"},
        %Feedme.Psc{href: nil, image: nil, start: "02:04:54.909", title: "Linux System Startup and Shutdown"},
        %Feedme.Psc{href: nil, image: nil, start: "02:16:16.477", title: "Der systemd Graph"},
        %Feedme.Psc{href: nil, image: nil, start: "02:29:54.685", title: "Network Setup mit systemd"},
        %Feedme.Psc{href: nil, image: nil, start: "02:42:10.547", title: "Ausblick und Fazit"}
      ],
      atom_links: [%Feedme.AtomLink{href: "http://cre.fm/cre209-das-linux-system#", rel: "http://podlove.org/deep-link", title: nil,
        type: nil},
        %Feedme.AtomLink{href: "https://flattr.com/submit/auto?user_id=timpritlove&language=de_DE&url=http%3A%2F%2Fcre.fm%2Fcre209-das-linux-system&title=CRE209+Das+Linux+System&description=Der+einst+von+Linus+Torvalds+geschaffene+Betriebssystemkernel+Linux+ist+eine+freie+Reimplementierung+der+UNIX+Betriebssystemfamilie+und+hat+sich+in+den+letzten+20+Jahren+sehr+eigenst%C3%A4ndig+entwickelt.+Der+Rest+des+Systems%2C+das+Userland%2C+hat+sich+aber+noch+sehr+stark+an+der+klassischen+Struktur+von+UNIX+orientiert.+Mit+der+Initiative+systemd+hat+sich+dies+ge%C3%A4ndert+und+es+entsteht+eine+sehr+eigenst%C3%A4ndige+Definition+einer+Linux-Systemebene%2C+die+sich+zwischen+Kernel+und+Anwendungen+entfaltet+und+dort+die+Regeln+der+Installation+und+Systemadministration+neu+definiert.%0D%0A%0D%0AIch+spreche+mit+dem+Initiator+des+Projekts%2C+Lennart+Poettering%2C+der+schon+vorher+verschiedene+Subsysteme+zur+Linux-Landschaft+beigetragen+hat+%C3%BCber+die+Motivation+und+Struktur+des+Projekts%2C+den+aktuellen+und+zuk%C3%BCnftigen+M%C3%B6glichkeiten+der+Software+und+welche+kulturellen+Auswirkungen+der+Einzug+einer+neuen+Abstraktionsebene+mit+sich+bringt.",
        rel: "payment", title: "Flattr this!", type: "text/html"}
      ]
    }
    assert entry.psc
    psc = entry.psc
    assert is_list(psc)
    assert length(psc) == 15
  end

  test "parse_entry with atom links", %{sample3: sample3} do
    entries = RSS2.parse_entries(sample3)
    assert entries
    [entry | _ ] = entries
    assert length(entry.atom_links) == 2
    [link | links] = entry.atom_links
    assert link.title == nil
    assert link.rel == "http://podlove.org/deep-link"
    assert link.href == "http://cre.fm/cre209-das-linux-system#"
    assert link.type == nil
    [link | _ ] = links
    assert link.title =="Flattr this!"
    assert link.rel == "payment"
    assert link.href == "https://flattr.com/submit/auto?user_id=timpritlove&language=de_DE&url=http%3A%2F%2Fcre.fm%2Fcre209-das-linux-system&title=CRE209+Das+Linux+System&description=Der+einst+von+Linus+Torvalds+geschaffene+Betriebssystemkernel+Linux+ist+eine+freie+Reimplementierung+der+UNIX+Betriebssystemfamilie+und+hat+sich+in+den+letzten+20+Jahren+sehr+eigenst%C3%A4ndig+entwickelt.+Der+Rest+des+Systems%2C+das+Userland%2C+hat+sich+aber+noch+sehr+stark+an+der+klassischen+Struktur+von+UNIX+orientiert.+Mit+der+Initiative+systemd+hat+sich+dies+ge%C3%A4ndert+und+es+entsteht+eine+sehr+eigenst%C3%A4ndige+Definition+einer+Linux-Systemebene%2C+die+sich+zwischen+Kernel+und+Anwendungen+entfaltet+und+dort+die+Regeln+der+Installation+und+Systemadministration+neu+definiert.%0D%0A%0D%0AIch+spreche+mit+dem+Initiator+des+Projekts%2C+Lennart+Poettering%2C+der+schon+vorher+verschiedene+Subsysteme+zur+Linux-Landschaft+beigetragen+hat+%C3%BCber+die+Motivation+und+Struktur+des+Projekts%2C+den+aktuellen+und+zuk%C3%BCnftigen+M%C3%B6glichkeiten+der+Software+und+welche+kulturellen+Auswirkungen+der+Einzug+einer+neuen+Abstraktionsebene+mit+sich+bringt."
    assert link.type == "text/html"
  end


  test "parse_entries", %{sample1: sample1, sample2: sample2} do
    [item1, item2] = RSS2.parse_entries(sample1)
    
    assert item1.title == "RSS Tutorial"
    assert item1.link == "http://www.w3schools.com/webservices"
    assert item1.description == "New RSS tutorial on W3Schools"

    assert item2.title == "XML Tutorial"
    assert item2.link == "http://www.w3schools.com/xml"
    assert item2.description == "New XML tutorial on W3Schools"

    [item1, item2] = RSS2.parse_entries(sample2)
    
    assert item1.title == nil
    assert item1.link == "http://www.w3schools.com/webservices"
    assert item1.description == nil

    assert item2.title == nil
    assert item2.link == "http://www.w3schools.com/xml"
    assert item2.description == nil
  end

  test "parse", %{sample1: sample1} do
    feed = RSS2.parse(sample1)

    assert feed == %Feedme.Feed{
      entries: [
        %Feedme.Entry{author: nil, categories: [], psc: [], comments: nil, description: "New RSS tutorial on W3Schools",
          enclosure: nil, guid: nil, itunes: %Feedme.Itunes{
            author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil, image: nil, isClosedCaptioned: nil,
            new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
          }, link: "http://www.w3schools.com/webservices", publication_date: nil, source: nil, title: "RSS Tutorial"
        },
        %Feedme.Entry{author: nil, categories: [], psc: [], comments: nil, description: "New XML tutorial on W3Schools", 
          enclosure: nil, guid: nil, itunes: %Feedme.Itunes{
            author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil, image: nil, isClosedCaptioned: nil,
            new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
          }, link: "http://www.w3schools.com/xml", publication_date: nil, source: nil, title: "XML Tutorial"
        }
      ],
      meta: %Feedme.MetaData{
        description: "Free web building tutorials",
        link: "http://www.w3schools.com", 
        title: "W3Schools Home Page",
        skip_days: [1,2],
        skip_hours: [1,2],
        image: %Feedme.Image{
          title: "Test Image",
          description: "test image...",
          url: "http://localhost/image"
        },
        last_build_date: %Timex.DateTime{
          calendar: :gregorian, day: 16,
          hour: 9, minute: 54, month: 8, ms: 0, second: 5,
          timezone: %Timex.TimezoneInfo{
            abbreviation: "UTC", from: :min,
            full_name: "UTC",
            offset_std: 0,
            offset_utc: 0,
            until: :max},
          year: 2015},
        publication_date: %Timex.DateTime{
          calendar: :gregorian,
          day: 15,
          hour: 9, minute: 54, month: 8, ms: 0, second: 5,
          timezone: %Timex.TimezoneInfo{
            abbreviation: "UTC",
            from: :min,
            full_name: "UTC",
            offset_std: 0,
            offset_utc: 0,
            until: :max
          },
          year: 2015
        },
        itunes: %Feedme.Itunes{
          author: nil, block: nil, category: nil, complete: nil, duration: nil, explicit: nil,
          image: nil, isClosedCaptioned: nil, new_feed_url: nil, order: nil, owner: nil, subtitle: nil, summary: nil
        }
      }
    }
  end
end
