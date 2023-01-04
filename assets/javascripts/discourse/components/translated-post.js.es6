import computed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  @computed("post.translated_text")
  loading(translated_text) {
    return translated_text === true ? true : false;
  },
});
