# frozen_string_literal: true

class CreateTranslationIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :discourse_translator_topic_translations,
                 %i[topic_id locale],
                 unique: true,
                 algorithm: :concurrently,
                 if_exists: true

    add_index :discourse_translator_topic_translations,
              %i[topic_id locale],
              unique: true,
              algorithm: :concurrently

    remove_index :discourse_translator_post_translations,
                 %i[post_id locale],
                 unique: true,
                 algorithm: :concurrently,
                 if_exists: true

    add_index :discourse_translator_post_translations,
              %i[post_id locale],
              unique: true,
              algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
