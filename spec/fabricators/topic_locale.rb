# frozen_string_literal: true
Fabricator(:topic_locale, from: DiscourseTranslator::TopicLocale) do
  topic
  detected_locale { %w[en de es en-GB ja pt pt-BR].sample }
end
