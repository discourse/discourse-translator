# frozen_string_literal: true
Fabricator(:post_locale, from: DiscourseTranslator::PostLocale) do
  post
  detected_locale { %w[en de es en-GB ja pt pt-BR].sample }
end
