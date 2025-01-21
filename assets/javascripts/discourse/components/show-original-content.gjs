import Component from "@glimmer/component";
import {service} from "@ember/service";
import {action} from "@ember/object";
import DButton from "discourse/components/d-button";

export default class ShowOriginalContent extends Component {
  @service router;

  static shouldRender(args) {
    console.log(args.post)
    return "is_translated" in args.post;
  }

  @action
  async showOriginal() {
    if (!!this.router.currentRoute.queryParams["language"]) {
      this.router.refresh();
    }
  }

  <template>
    <div class="discourse-translator_toggle-original">
      <DButton class="btn-tiny" @action={{this.showOriginal}}>View original</DButton>
    </div>
  </template>
}
