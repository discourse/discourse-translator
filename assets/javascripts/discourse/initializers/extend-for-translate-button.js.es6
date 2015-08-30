import PostMenuComponent from 'discourse/components/post-menu';
import { Button } from 'discourse/components/post-menu';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { renderSpinner } from 'discourse/helpers/loading-spinner';

export default {
  name: 'extend-for-translate-button',
  initialize: function() {
    PostMenuComponent.registerButton(function(visibleButtons){
      let [action, label] = !this.get('isTranslated') ? ['translate', 'translator.view_translation'] : ['hideTranslation', 'translator.hide_translation'];
      const position = visibleButtons.map(button => button.action).indexOf('like');
      visibleButtons.splice(position + 1, 0, new Button(action, label, 'globe'));
    });

    PostMenuComponent.reopen({
      isTranslated: false,

      @observes('isTranslated')
      toggleTranslation() {
        this.rerender();
      },

      clickTranslate: function(post) {
        const self = this,
              $cookedElement = this._cookedElement(post);

        this.set('isTranslated', true);
        $cookedElement.after(renderSpinner('small'));

        Discourse.ajax('/translator/translate', {
          type: 'POST',
          data: { post_id: post.get('id') }
        }).then(function(res) {
          const cooked = post.get('cooked');
          $cookedElement.next('.spinner').remove();

          $cookedElement.after(
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
        const $cookedElement = this._cookedElement(post);
        $cookedElement.next('.spinner').remove();
        $cookedElement.next('.post-translation').remove();
        this.set('isTranslated', false);
        return false;
      },

      _cookedElement: function(post) {
        return $(`#post-cloak-${post.get('post_number')} .cooked`);
      }
    });
  }
};
