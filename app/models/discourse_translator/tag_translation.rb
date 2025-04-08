# frozen_string_literal: true

module DiscourseTranslator
  class TagTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_tag_translations"

    belongs_to :tag

    validates :tag_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :tag_id }
  end
end
