# frozen_string_literal: true
Fabricator(:topic_translation, from: DiscourseTranslator::TopicTranslation) do
  topic
  locale { %w[en de es en-GB ja pt pt-BR].sample }
  translation do |attrs|
    {
      "en" => "Hello",
      "de" => "Hallo",
      "es" => "Hola",
      "en-GB" => "Hello",
      "ja" => "こんにちは",
      "pt" => "Olá",
      "pt-BR" => "Olá",
    }[
      attrs[:locale]
    ]
  end
end
