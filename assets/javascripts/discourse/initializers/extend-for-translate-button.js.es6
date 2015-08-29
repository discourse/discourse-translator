import PostMenuComponent from 'discourse/components/post-menu';
import { Button } from 'discourse/components/post-menu';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default {
  name: 'extend-for-translate-button',
  initialize: function() {
    PostMenuComponent.registerButton(function(visibleButtons){
      if (!this.get('isTranslated')) {
        visibleButtons.splice(0, 0, new Button('translate', 'translator.view_translation', 'globe'));
      } else {
        visibleButtons.splice(0, 0, new Button('hideTranslation', 'translator.hide_translation', 'globe'));
      }
    });

    PostMenuComponent.reopen({
      isTranslated: false,

      toggleTranslation: function() {
        this.rerender();
      }.observes('isTranslated'),

      clickTranslate: function(post) {
        const self = this;
        this.set('isTranslated', true);

        Discourse.ajax('/translator/translate', {
          type: 'POST',
          data: { post_id: post.get('id') }
        }).then(function(res) {
          const cooked = post.get('cooked');
          self._cookedElement(post).after(
            `<div class="post-translation">
              <hr>
              <div class="post-attribution">
                ${I18n.t('translator.translated_from', {
                  language: res.detected_lang,
                  translator: self.siteSettings.translator
                })}
              </div>
              ${res.translation}
            </div>`
          );
        }).catch(function(error) {
          popupAjaxError(error);
          self.set('isTranslated', false);
        });

        return false;
      },

      clickHideTranslation: function(post) {
        this._cookedElement(post).next('.post-translation').remove();
        this.set('isTranslated', false);
        return false;
      },

      _cookedElement: function(post) {
        return $(`#post-cloak-${post.get('post_number')} .cooked`);
      }
    });
  }
};
