# frozen_string_literal: true

module DiscourseTranslator
  class PostTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_post_translations"

    belongs_to :post

    validates :post_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :post_id }

    def self.translation_for(post_id, locale)
      find_by(post_id: post_id, locale: locale)&.translation
    end
  end
end
