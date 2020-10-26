defmodule PageGenConsumer do
  use KafkaEx.GenConsumer

  alias KafkaEx.Protocol.Fetch.Message

  require Logger

  # Disclaimer: these are just words a programmer who is prejudiced towards some
  # settings or technologies might view as "good" or "bad". They're not intended
  # as objectively good or bad, just a little bit fun.
  @good_words ["python", "elixir", "kubernetes", "k8s", "docker", "well paid", "hyvä palkka"]
  @bad_words ["java", "enterprise", "php", "Microsoft"]

  # note - messages are delivered in batches
  def handle_message_set(message_set, state) do
    word_counts = existing_word_counts()
    IO.inspect(word_counts, label: "previous_word_counts")
    word_counts = Enum.reduce(message_set, word_counts,
      fn(%Message{value: message} , wc) ->
        handle_message(wc, message)
      end
    )
    IO.inspect(word_counts, label: "total_word_counts")
    save_word_counts(word_counts)
    kafka_msg = Jason.encode!(word_counts)
    KafkaEx.produce("wordcounts", 0, kafka_msg)
    {:async_commit, state}
  end

  defp handle_message(word_counts, message) when is_map(word_counts) and is_binary(message) do
    jsonmessage = Jason.decode!(message)
    domain = jsonmessage["domain"]
    url = jsonmessage["url"]
    text = jsonmessage["text"]

    word_counts = put_if_doesnt_exist(word_counts, domain,
                                      %{"good_words" => %{}, "bad_words" => %{}})
    IO.inspect(word_counts, label: "initial_word_counts")
    good_word_counts = word_counts(@good_words, text)
    bad_word_counts = word_counts(@bad_words, text)


    IO.inspect(good_word_counts, label: "good word counts")
    IO.inspect(bad_word_counts, label: "bad word counts")


    word_counts = Enum.reduce(good_word_counts, word_counts,
      fn({word, match_count}, wc) ->
        update_in(
        wc[domain]["good_words"][word],
        &((if &1 != nil, do: &1 + match_count, else: match_count))
      )
      end
    )

    word_counts = Enum.reduce(bad_word_counts, word_counts,
      fn({word, match_count}, wc) ->
        update_in(
        wc[domain]["bad_words"][word],
        &((if &1 != nil, do: &1 + match_count, else: match_count))
      )
      end
    )

    IO.inspect(word_counts, label: "handle_message_done_word_counts")
    word_counts
  end

  defp put_if_doesnt_exist(map, key, value) do
    if Map.get(map, key) == nil do
      Map.put(map, key, value)
    else
      map
    end
  end

  defp existing_word_counts() do
    # We could just grab this from the end of the wordcounts
    # topic instead.
    {:ok, table} = :dets.open_file(:word_counts, type: :set)
    counts = List.first(:dets.lookup(table, "wordcounts"))
    :dets.close(:word_counts)
    if counts != nil do
      {_, word_counts} = counts
      word_counts
    else
      %{}
    end
  end

  def save_word_counts(word_counts) do
    {:ok, table} = :dets.open_file(:word_counts, type: :set)
    :dets.insert(table, {"wordcounts", word_counts})
    :dets.close(:chapters)
  end

  defp word_counts(words, text) do
    for w <- words do
      "\s#{w}\s"
      |> Regex.compile!("i")
      |> Regex.run(text)
      |> (fn(matches) -> (if matches != nil, do: length(matches), else: 0) end).()
      |> (fn(match_count) -> {w, match_count} end).()
    end
  end
end
