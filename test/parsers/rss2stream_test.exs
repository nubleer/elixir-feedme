defmodule Feedme.Test.Parsers.RSS2Stream do
  use ExUnit.Case #, async: true

  alias Feedme.Parsers.RSS2Stream

  setup do
    {:ok, sample1} = File.read "test/fixtures/rss2/sample1.xml"
    # sample2 = XmlNode.from_file("test/fixtures/rss2/sample2.xml")
    {:ok, sample3} = File.read("test/fixtures/rss2/cre.xml")
    # sample4 = XmlNode.from_file("test/fixtures/rss2/wpt.xml")
    # big_sample = XmlNode.from_file("test/fixtures/rss2/bigsample.xml")

    {:ok, [
      sample1: sample1, 
      # sample2: sample2, 
      sample3: sample3, 
      # sample4: sample4, 
      # big_sample: big_sample
    ]}
  end


  test "parser basics and partial xml error handling" do
    result = RSS2Stream.parse("<root></root>")
    assert match? {:error, :no_rss_root}, result

    result = RSS2Stream.parse("<root></root>")
    assert match? {:error, :no_rss_root}, result

    result = RSS2Stream.parse("<root>")
    assert match? {:error, :no_rss_root}, result

    result = RSS2Stream.parse("<rss></rss>")
    assert match? {:ok, _}, result

    # result = RSS2Stream.parse("<rss>")
    # assert match? {:error, :parser_timeout}, result
  end

  test "small input", %{sample1: sample1} do
    result = RSS2Stream.parse(sample1)
    IO.inspect result
    assert match? {:ok, _}, result
  end
  
  test "large input", %{sample3: sample3} do
    result = RSS2Stream.parse(sample3)
    IO.inspect result
    assert match? {:ok, _}, result
  end
end
