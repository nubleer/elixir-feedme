defmodule FeedmeTest do
  use ExUnit.Case, async: false

  import Mock

  setup do
    {:ok, wrong} = File.read("test/fixtures/wrong.xml")
    {:ok, rss2} = File.read("test/fixtures/rss2/bigsample.xml")
    {:ok, podcast_cre} = File.read("test/fixtures/rss2/cre.xml")

    {:ok, [rss2: rss2, wrong: wrong, podcast_cre: podcast_cre]}
  end


  test "parse2", %{podcast_cre: podcast_cre} do
    assert {:ok, feed} = Feedme.parse(podcast_cre)
    assert "CRE: Technik, Kultur, Gesellschaft" = feed.meta.title
    assert nil != feed.meta.itunes
    assert "Metaebene Personal Media - Tim Pritlove" = feed.meta.itunes.author
  end


end
