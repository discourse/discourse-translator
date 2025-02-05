# frozen_string_literal: true

module DiscourseTranslator
  class PostLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_post_locales"

    belongs_to :post

    validates :post_id, presence: true, uniqueness: true
    validates :detected_locale, presence: true
  end
end
