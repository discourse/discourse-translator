# frozen_string_literal: true

module DiscourseTranslator
  class TagLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_tag_locales"

    belongs_to :tag

    validates :tag_id, presence: true
    validates :detected_locale, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_translator_tag_locales
#
#  id              :bigint           not null, primary key
#  tag_id          :integer          not null
#  detected_locale :string(20)       not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
