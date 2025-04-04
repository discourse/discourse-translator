# frozen_string_literal: true

module DiscourseTranslator
  class CategoryLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_category_locales"

    belongs_to :category

    validates :category_id, presence: true
    validates :detected_locale, presence: true
  end
end
