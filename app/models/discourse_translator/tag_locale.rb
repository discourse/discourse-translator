# frozen_string_literal: true

module DiscourseTranslator
  class TagLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_tag_locales"

    belongs_to :tag

    validates :tag_id, presence: true
    validates :detected_locale, presence: true
  end
end
