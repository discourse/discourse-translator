# frozen_string_literal: true

module DiscourseTranslator
  class CategoryLocale < ActiveRecord::Base
    self.table_name = "discourse_translator_category_locales"

    belongs_to :category

    validates :category_id, presence: true
    validates :detected_locale, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_translator_category_locales
#
#  id              :bigint           not null, primary key
#  category_id     :integer          not null
#  detected_locale :string(20)       not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
