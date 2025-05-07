# frozen_string_literal: true

describe DiscourseTranslator::AutomaticTranslations do
  before { SiteSetting.translator_enabled = true }

  describe "upon post process cooked" do
    it "enqueues detect post locale and translate post job" do
      SiteSetting.experimental_content_localization = true
      post = Fabricate(:post)
      CookedPostProcessor.new(post).post_process

      expect_job_enqueued(job: :detect_translate_post, args: { post_id: post.id })
    end

    it "does not enqueue if setting disabled" do
      SiteSetting.experimental_content_localization = false
      post = Fabricate(:post)
      CookedPostProcessor.new(post).post_process

      expect(job_enqueued?(job: :detect_translate_post, args: { post_id: post.id })).to eq false
    end
  end
end
