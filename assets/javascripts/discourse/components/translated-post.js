import Component from "@ember/component";
import computed from "discourse-common/utils/decorators";

export default Component.extend({
  @computed("post.translated_text")
  loading(translated_text) {
    return translated_text === true ? true : false;
  },
});
