# frozen_string_literal: true

module DiscourseTranslator
  class CategoryTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_category_translations"

    belongs_to :category

    validates :category_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :category_id }
  end
end
