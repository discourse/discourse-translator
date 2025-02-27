import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class TranslatorService extends Service {
  @service siteSettings;
  @service appEvents;
  @service documentTitle;

  async translatePost(post) {
    const response = await ajax("/translator/translate", {
      type: "POST",
      data: { post_id: post.id },
    });

    post.detectedLang = response.detected_lang;
    post.translatedText = response.translation;
    post.translatedTitle = response.title_translation;
    if (this.siteSettings.experimental_topic_translation) {
      if (post.post_number === 1) {
        post.topic.set("fancy_title", response.title_translation);
        this.appEvents.trigger("header:update-topic", post.topic);
        this.documentTitle.setTitle(response.title_translation);
      }
      post.set("cooked", response.translation);
      post.set("can_translate", false);
      this.appEvents.trigger("post-stream:refresh", { id: post.id });
    }
  }

  clearPostTranslation(post) {
    post.detectedLang = null;
    post.translatedText = null;
    post.translatedTitle = null;
  }
}
