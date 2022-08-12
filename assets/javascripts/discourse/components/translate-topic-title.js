import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "span",

  actions: {
    translate() {
      const topic = this.topic;
      const originalTitle = topic.title;

      this.set("translating", true);

      return ajax("/translator/translate", {
        type: "POST",
        data: { topic_id: topic.id },
      })
        .then(function (res) {
          topic.setProperties({
            title: res.translation,
            fancy_title: res.translation,
            original_title: originalTitle,
            title_language: res.detected_lang,
            title_translated: true,
          });
        })
        .finally(() => {
          this.set("translating", false);
        });
    },
  },
});
