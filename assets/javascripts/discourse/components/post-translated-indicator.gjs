import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostTranslatedIndicator extends Component {
  static shouldRender(args) {
    console.log(args);
    return true;
    return (
      args.topic.is_translated ||
      args.topic.postStream.posts.some(({ is_translated }) => is_translated)
    );
  }

  <template>
    <div class="discourse-translator_post-translated-indicator">
      Hello
    </div>
  </template>
}
