# frozen_string_literal: true

module DiscourseTranslator
  class TopicLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_topic_locales"

    belongs_to :topic

    validates :topic_id, presence: true, uniqueness: true
    validates :detected_locale, presence: true
  end
end
