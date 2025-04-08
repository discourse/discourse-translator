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

# == Schema Information
#
# Table name: discourse_translator_tag_translations
#
#  id          :bigint           not null, primary key
#  tag_id      :integer          not null
#  locale      :string           not null
#  translation :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_tag_translations_on_tag_id_and_locale  (tag_id,locale) UNIQUE
#
