require "rails_helper"

def user_from_authorization_service(service_name, signed_in_resource = nil, cta_variant = "navbar_basic")
  auth = OmniAuth.config.mock_auth[service_name]
  Authentication::Authenticator.call(
    auth,
    current_user: signed_in_resource,
    cta_variant: cta_variant,
  )
end

def mock_username(provider_name, username)
  if provider_name == :apple
    OmniAuth.config.mock_auth[provider_name].info.first_name = username
  else
    OmniAuth.config.mock_auth[provider_name].info.nickname = username
  end
end

def provider_username(service_name)
  auth_payload = OmniAuth.config.mock_auth[service_name]
  provider_class = Authentication::Providers.get!(auth_payload.provider)
  provider_class.new(auth_payload).user_nickname
end

RSpec.describe User, type: :model do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:org) { create(:organization) }

  before { omniauth_mock_providers_payload }

  describe "validations" do
    describe "builtin validations" do
      subject { user }

      it { is_expected.to have_one(:profile).dependent(:destroy) }

      it { is_expected.to have_many(:access_grants).class_name("Doorkeeper::AccessGrant").dependent(:delete_all) }
      it { is_expected.to have_many(:access_tokens).class_name("Doorkeeper::AccessToken").dependent(:delete_all) }
      it { is_expected.to have_many(:ahoy_events).class_name("Ahoy::Event").dependent(:destroy) }
      it { is_expected.to have_many(:ahoy_visits).class_name("Ahoy::Visit").dependent(:destroy) }
      it { is_expected.to have_many(:api_secrets).dependent(:destroy) }
      it { is_expected.to have_many(:articles).dependent(:destroy) }
      it { is_expected.to have_many(:audit_logs).dependent(:nullify) }
      it { is_expected.to have_many(:badge_achievements).dependent(:destroy) }
      it { is_expected.to have_many(:badges).through(:badge_achievements) }
      it { is_expected.to have_many(:chat_channel_memberships).dependent(:destroy) }
      it { is_expected.to have_many(:chat_channels).through(:chat_channel_memberships) }
      it { is_expected.to have_many(:collections).dependent(:destroy) }
      it { is_expected.to have_many(:comments).dependent(:destroy) }
      it { is_expected.to have_many(:credits).dependent(:destroy) }
      it { is_expected.to have_many(:display_ad_events).dependent(:destroy) }
      it { is_expected.to have_many(:email_authorizations).dependent(:delete_all) }
      it { is_expected.to have_many(:email_messages).class_name("Ahoy::Message").dependent(:destroy) }
      it { is_expected.to have_many(:endorsements).dependent(:destroy) }
      it { is_expected.to have_many(:field_test_memberships).class_name("FieldTest::Membership").dependent(:destroy) }
      it { is_expected.to have_many(:github_repos).dependent(:destroy) }
      it { is_expected.to have_many(:html_variants).dependent(:destroy) }
      it { is_expected.to have_many(:identities).dependent(:destroy) }
      it { is_expected.to have_many(:identities_enabled) }
      it { is_expected.to have_many(:listings).dependent(:destroy) }
      it { is_expected.to have_many(:mentions).dependent(:destroy) }
      it { is_expected.to have_many(:messages).dependent(:destroy) }
      it { is_expected.to have_many(:notes).dependent(:destroy) }
      it { is_expected.to have_many(:notification_subscriptions).dependent(:destroy) }
      it { is_expected.to have_many(:notifications).dependent(:destroy) }
      it { is_expected.to have_many(:organization_memberships).dependent(:destroy) }
      it { is_expected.to have_many(:organizations).through(:organization_memberships) }
      it { is_expected.to have_many(:page_views).dependent(:nullify) }
      it { is_expected.to have_many(:poll_skips).dependent(:destroy) }
      it { is_expected.to have_many(:poll_votes).dependent(:destroy) }
      it { is_expected.to have_many(:profile_pins).dependent(:delete_all) }
      it { is_expected.to have_many(:rating_votes).dependent(:nullify) }
      it { is_expected.to have_many(:reactions).dependent(:destroy) }
      it { is_expected.to have_many(:response_templates).dependent(:destroy) }
      it { is_expected.to have_many(:source_authored_user_subscriptions).dependent(:destroy) }
      it { is_expected.to have_many(:subscribed_to_user_subscriptions).dependent(:destroy) }
      it { is_expected.to have_many(:subscribers).dependent(:destroy) }
      it { is_expected.to have_many(:tweets).dependent(:nullify) }
      it { is_expected.to have_many(:webhook_endpoints).class_name("Webhook::Endpoint").dependent(:delete_all) }

      # rubocop:disable RSpec/NamedSubject
      it do
        expect(subject).to have_many(:access_grants)
          .class_name("Doorkeeper::AccessGrant")
          .with_foreign_key("resource_owner_id")
          .dependent(:delete_all)
      end

      it do
        expect(subject).to have_many(:access_tokens)
          .class_name("Doorkeeper::AccessToken")
          .with_foreign_key("resource_owner_id")
          .dependent(:delete_all)
      end

      it do
        expect(subject).to have_many(:affected_feedback_messages)
          .class_name("FeedbackMessage")
          .with_foreign_key("affected_id")
          .dependent(:nullify)
      end

      it do
        expect(subject).to have_many(:authored_notes)
          .class_name("Note")
          .with_foreign_key("author_id")
          .dependent(:delete_all)
      end

      it do
        expect(subject).to have_many(:backup_data)
          .class_name("BackupData")
          .with_foreign_key("instance_user_id")
          .dependent(:delete_all)
      end

      it do
        expect(subject).to have_many(:blocked_blocks)
          .class_name("UserBlock")
          .with_foreign_key("blocked_id")
          .dependent(:delete_all)
      end

      it do
        expect(subject).to have_many(:blocker_blocks)
          .class_name("UserBlock")
          .with_foreign_key("blocker_id")
          .dependent(:delete_all)
      end

      it do
        expect(subject).to have_many(:created_podcasts)
          .class_name("Podcast")
          .with_foreign_key(:creator_id)
          .dependent(:nullify)
      end

      it do
        expect(subject).to have_many(:offender_feedback_messages)
          .class_name("FeedbackMessage")
          .with_foreign_key(:offender_id)
          .dependent(:nullify)
      end

      it do
        expect(subject).to have_many(:reporter_feedback_messages)
          .class_name("FeedbackMessage")
          .with_foreign_key(:reporter_id)
          .dependent(:nullify)
      end
      # rubocop:enable RSpec/NamedSubject

      it { is_expected.not_to allow_value("#xyz").for(:bg_color_hex) }
      it { is_expected.not_to allow_value("#xyz").for(:text_color_hex) }
      it { is_expected.not_to allow_value("AcMe_1%").for(:username) }
      it { is_expected.to allow_value("#aabbcc").for(:bg_color_hex) }
      it { is_expected.to allow_value("#aabbcc").for(:text_color_hex) }
      it { is_expected.to allow_value("#abc").for(:bg_color_hex) }
      it { is_expected.to allow_value("#abc").for(:text_color_hex) }
      it { is_expected.to allow_value("AcMe_1").for(:username) }

      it { is_expected.to validate_inclusion_of(:inbox_type).in_array(%w[open private]) }
      it { is_expected.to validate_length_of(:available_for).is_at_most(500).allow_nil }
      it { is_expected.to validate_length_of(:behance_url).is_at_most(100).allow_nil }
      it { is_expected.to validate_length_of(:currently_hacking_on).is_at_most(500).allow_nil }
      it { is_expected.to validate_length_of(:currently_learning).is_at_most(500).allow_nil }
      it { is_expected.to validate_length_of(:education).is_at_most(100).allow_nil }
      it { is_expected.to validate_length_of(:email).is_at_most(50).allow_nil }
      it { is_expected.to validate_length_of(:employer_name).is_at_most(100).allow_nil }
      it { is_expected.to validate_length_of(:employer_url).is_at_most(100).allow_nil }
      it { is_expected.to validate_length_of(:employment_title).is_at_most(100).allow_nil }
      it { is_expected.to validate_length_of(:inbox_guidelines).is_at_most(250).allow_nil }
      it { is_expected.to validate_length_of(:location).is_at_most(100).allow_nil }
      it { is_expected.to validate_length_of(:mostly_work_with).is_at_most(500).allow_nil }
      it { is_expected.to validate_length_of(:name).is_at_most(100).is_at_least(1) }
      it { is_expected.to validate_length_of(:password).is_at_most(100).is_at_least(8) }
      it { is_expected.to validate_length_of(:summary).is_at_most(1300).allow_nil }
      it { is_expected.to validate_length_of(:username).is_at_most(30).is_at_least(2) }
      it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
      it { is_expected.to validate_url_of(:employer_url) }
      it { is_expected.to validate_url_of(:website_url) }

      Authentication::Providers.username_fields.each do |username_field|
        it { is_expected.to validate_uniqueness_of(username_field).allow_nil }
      end
    end

    it "validates username against reserved words" do
      user = build(:user, username: "readinglist")
      expect(user).not_to be_valid
      expect(user.errors[:username].to_s).to include("reserved")
    end

    it "takes organization slug into account" do
      create(:organization, slug: "lightalloy")
      user = build(:user, username: "lightalloy")
      expect(user).not_to be_valid
      expect(user.errors[:username].to_s).to include("taken")
    end

    it "takes podcast slug into account" do
      create(:podcast, slug: "lightpodcast")
      user = build(:user, username: "lightpodcast")
      expect(user).not_to be_valid
      expect(user.errors[:username].to_s).to include("taken")
    end

    it "takes page slug into account" do
      create(:page, slug: "page_yo")
      user = build(:user, username: "page_yo")
      expect(user).not_to be_valid
      expect(user.errors[:username].to_s).to include("taken")
    end

    it "validates can_send_confirmation_email for existing user" do
      user = create(:user)
      limiter = RateLimitChecker.new(user)
      allow(user).to receive(:rate_limiter).and_return(limiter)
      allow(limiter).to receive(:limit_by_action).and_return(true)
      allow(limiter).to receive(:track_limit_by_action)
      user.update(email: "new_email@yo.com")

      expect(user).not_to be_valid
      expect(user.errors[:email].to_s).to include("confirmation could not be sent. Rate limit reached")
      expect(limiter).to have_received(:track_limit_by_action).with(:send_email_confirmation).twice
    end

    it "validates update_rate_limit for existing user" do
      user = create(:user)
      limiter = RateLimitChecker.new(user)
      allow(user).to receive(:rate_limiter).and_return(limiter)
      allow(limiter).to receive(:limit_by_action).and_return(true)
      allow(limiter).to receive(:track_limit_by_action)
      user.update(articles_count: 5)

      expect(user).not_to be_valid
      expect(user.errors[:base].to_s).to include("could not be saved. Rate limit reached")
      expect(limiter).to have_received(:track_limit_by_action).with(:user_update).twice
    end
  end

  describe "#after_commit" do
    it "on update enqueues job to index user to elasticsearch" do
      user.save
      sidekiq_assert_enqueued_with(job: Search::IndexWorker, args: [described_class.to_s, user.id]) do
        user.save
      end
    end

    it "on update syncs elasticsearch data" do
      allow(user).to receive(:sync_related_elasticsearch_docs)
      user.save
      expect(user).to have_received(:sync_related_elasticsearch_docs)
    end

    it "on destroy enqueues job to delete user from elasticsearch" do
      user.save
      sidekiq_assert_enqueued_with(job: Search::RemoveFromIndexWorker,
                                   args: [described_class::SEARCH_CLASS.to_s, user.id]) do
        user.destroy
      end
    end
  end

  context "when callbacks are triggered before validation" do
    let(:user) { build(:user) }

    Authentication::Providers.username_fields.each do |username_field|
      describe username_field do
        it "sets #{username_field} to nil if empty" do
          user.assign_attributes(username_field => "")
          user.validate!
          expect(user.attributes[username_field.to_s]).to be_nil
        end

        it "does not change a valid name" do
          user.assign_attributes(username_field => "hello")
          user.validate!
          expect(user.attributes[username_field.to_s]).to eq("hello")
        end
      end
    end

    describe "#email" do
      it "sets email to nil if empty" do
        user.email = ""
        user.validate!
        expect(user.email).to eq(nil)
      end

      it "does not change a valid name" do
        user.email = "anna@example.com"
        user.validate!
        expect(user.email).to eq("anna@example.com")
      end
    end

    describe "#username" do
      it "receives a temporary username if none is given" do
        user.username = ""
        user.validate!
        expect(user.username).not_to be_blank
      end

      it "does not allow to change to a username that is taken" do
        user.username = other_user.username
        expect(user).not_to be_valid
      end

      it "does not allow to change to a username that is taken by an organization" do
        user.username = create(:organization).slug
        expect(user).not_to be_valid
      end
    end

    describe "#website_url" do
      it "does not accept invalid website url" do
        user.website_url = "ben.com"
        expect(user).not_to be_valid
      end

      it "accepts valid http website url" do
        user.website_url = "http://ben.com"
        expect(user).to be_valid
      end
    end

    describe "#mastodon_url" do
      it "accepts valid https mastodon url" do
        user.mastodon_url = "https://mastodon.social/@test"
        expect(user).to be_valid
      end

      it "does not accept a denied mastodon instance" do
        user.mastodon_url = "https://SpammyMcSpamface.com/"
        expect(user).not_to be_valid
      end

      it "does not accept invalid mastodon url" do
        user.mastodon_url = "mastodon.social/@test"
        expect(user).not_to be_valid
      end

      it "does not accept an invalid url" do
        user.mastodon_url = "ben .com"
        expect(user).not_to be_valid
      end
    end

    describe "#facebook_url" do
      it "accepts valid https facebook url", :aggregate_failures do
        %w[thepracticaldev thepracticaldev/ the.practical.dev].each do |username|
          user.facebook_url = "https://facebook.com/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid facebook url" do
        user.facebook_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#youtube_url" do
      it "accepts valid https youtube url", :aggregate_failures do
        %w[thepracticaldev thepracticaldev/ the.practical.dev].each do |username|
          user.youtube_url = "https://youtube.com/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid youtube url" do
        user.youtube_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#behance_url" do
      it "accepts valid https behance url", :aggregate_failures do
        %w[jess jess/ je-ss jes_ss].each do |username|
          user.behance_url = "https://behance.net/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid behance url" do
        user.behance_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#twitch_url" do
      it "does not accept invalid twitch url" do
        user.twitch_url = "ben.com"
        expect(user).not_to be_valid
      end

      it "accepts valid https twitch url", :aggregate_failures do
        %w[pandyzhao pandyzhao/ PandyZhao_ pandy_Zhao].each do |username|
          user.twitch_url = "https://twitch.tv/#{username}"
          expect(user).to be_valid
        end
      end
    end

    describe "#stackoverflow_url" do
      it "accepts valid https stackoverflow url", :aggregate_failures do
        %w[pandyzhao pandyzhao/ pandy-zhao].each do |username|
          user.stackoverflow_url = "https://stackoverflow.com/users/7381391/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid stackoverflow url" do
        user.stackoverflow_url = "ben.com"
        expect(user).not_to be_valid
      end

      it "accepts valid stackoverflow sub community url", :aggregate_failures do
        %w[pt ru es ja].each do |subcommunity|
          user.stackoverflow_url = "https://#{subcommunity}.stackoverflow.com/users/7381391/mazen"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid stackoverflow sub community url" do
        user.stackoverflow_url = "https://fr.stackoverflow.com/users/7381391/mazen"
        expect(user).not_to be_valid
      end
    end

    describe "#linkedin_url" do
      it "accepts valid https linkedin url", :aggregate_failures do
        %w[jessleenyc jessleenyc/ jess-lee-nyc].each do |username|
          user.linkedin_url = "https://linkedin.com/in/#{username}"
          expect(user).to be_valid
        end
      end

      it "accepts valid country specific https linkedin url" do
        user.linkedin_url = "https://mx.linkedin.com/in/jessleenyc"
        expect(user).to be_valid
      end

      it "does not accept three letters country codes in http linkedin url" do
        user.linkedin_url = "http://mex.linkedin.com/in/jessleenyc"
        expect(user).not_to be_valid
      end

      it "does not accept three letters country codes in https linkedin url" do
        user.linkedin_url = "https://mex.linkedin.com/in/jessleenyc"
        expect(user).not_to be_valid
      end

      it "does not accept invalid linkedin url" do
        user.linkedin_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#dribbble_url", :aggregate_failures do
      it "accepts valid https dribbble url" do
        %w[jess jess/ je-ss je_ss].each do |username|
          user.dribbble_url = "https://dribbble.com/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid dribbble url" do
        user.dribbble_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#medium_url" do
      it "accepts valid https medium url", :aggregate_failures do
        %w[jess jess/ je-ss je_ss].each do |username|
          user.medium_url = "https://medium.com/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid medium url" do
        user.medium_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#instagram_url" do
      it "does not accept invalid instagram url" do
        user.instagram_url = "ben.com"
        expect(user).not_to be_valid
      end

      it "accepts valid instagram url", :aggregate_failures do
        %w[jess je_ss je_ss.tt A.z.E.r.T.y].each do |username|
          user.instagram_url = "https://instagram.com/#{username}"
          expect(user).to be_valid
        end
      end
    end

    describe "#gitlab_url" do
      it "accepts valid https gitlab url", :aggregate_failures do
        %w[jess jess/ je-ss je_ss].each do |username|
          user.gitlab_url = "https://gitlab.com/#{username}"
          expect(user).to be_valid
        end
      end

      it "does not accept invalid gitlab url" do
        user.gitlab_url = "ben.com"
        expect(user).not_to be_valid
      end
    end

    describe "#employer_url" do
      it "does not accept invalid employer url" do
        user.employer_url = "ben.com"
        expect(user).not_to be_valid
      end

      it "does accept valid http employer url" do
        user.employer_url = "http://ben.com"
        expect(user).to be_valid
      end

      it "does accept valid https employer url" do
        user.employer_url = "https://ben.com"
        expect(user).to be_valid
      end
    end

    describe "#config_theme" do
      it "accepts valid theme" do
        user.config_theme = "night theme"
        expect(user).to be_valid
      end

      it "does not accept invalid theme" do
        user.config_theme = "no night mode"
        expect(user).not_to be_valid
      end
    end

    describe "#config_font" do
      it "accepts valid font" do
        user.config_font = "sans serif"
        expect(user).to be_valid
      end

      it "does not accept invalid font" do
        user.config_font = "goobledigook"
        expect(user).not_to be_valid
      end
    end

    describe "#config_navbar" do
      it "accepts valid navbar" do
        user.config_navbar = "static"
        expect(user).to be_valid
      end

      it "does not accept invalid navbar" do
        user.config_navbar = "not valid navbar input"
        expect(user).not_to be_valid
      end
    end

    context "when the past value is relevant" do
      let(:user) { create(:user) }

      it "changes old_username and old_old_username properly if username changes" do
        old_username = user.username
        random_new_username = "username_#{rand(100_000_000)}"
        user.update(username: random_new_username)
        expect(user.username).to eq(random_new_username)
        expect(user.old_username).to eq(old_username)

        new_username = user.username
        user.update(username: "username_#{rand(100_000_000)}")
        expect(user.old_username).to eq(new_username)
        expect(user.old_old_username).to eq(old_username)
      end

      it "enforces summary length validation if previous summary was valid" do
        user.summary = "0" * 999
        user.save(validate: false)
        user.summary = "0" * 999
        expect(user).to be_valid
      end

      it "does not enforce summary validation if previous summary was invalid" do
        user = build(:user, summary: "0" * 999)
        expect(user).not_to be_valid
      end
    end
  end

  context "when callbacks are triggered before and after create" do
    let(:user) { create(:user, email: nil) }

    describe "#language_settings" do
      it "sets correct language_settings by default" do
        expect(user.language_settings).to eq("preferred_languages" => %w[en])
      end

      it "sets correct language_settings by default after the jobs are processed" do
        sidekiq_perform_enqueued_jobs do
          expect(user.language_settings).to eq("preferred_languages" => %w[en])
        end
      end
    end

    describe "#estimated_default_language" do
      it "estimates default language to be nil" do
        sidekiq_perform_enqueued_jobs do
          expect(user.estimated_default_language).to be(nil)
        end
      end

      it "estimates default language to be japanese with .jp email" do
        user = nil

        sidekiq_perform_enqueued_jobs do
          user = create(:user, email: "ben@hello.jp")
        end

        expect(user.reload.estimated_default_language).to eq("ja")
      end

      it "estimates default language from Twitter identity" do
        new_user = nil

        sidekiq_perform_enqueued_jobs(only: Users::EstimateDefaultLanguageWorker) do
          new_user = user_from_authorization_service(:twitter)
        end

        lang = new_user.identities.last.auth_data_dump.extra.raw_info.lang
        expect(new_user.reload.estimated_default_language).to eq(lang)
      end
    end

    describe "#send_welcome_notification" do
      let(:mascot_account) { create(:user) }
      let!(:set_up_profile_broadcast) { create(:set_up_profile_broadcast) }

      before do
        allow(described_class).to receive(:mascot_account).and_return(mascot_account)
      end

      it "sends a setup welcome notification when an active broadcast exists" do
        new_user = nil
        sidekiq_perform_enqueued_jobs do
          new_user = create(:user)
        end
        expect(new_user.reload.notifications.count).to eq(1)
        expect(new_user.reload.notifications.first.notifiable).to eq(set_up_profile_broadcast)
      end

      it "does not send a setup welcome notification without an active broadcast" do
        set_up_profile_broadcast.update!(active: false)
        new_user = nil
        sidekiq_perform_enqueued_jobs do
          new_user = create(:user)
        end
        expect(new_user.reload.notifications.count).to eq(0)
      end
    end

    describe "#preferred_languages_array" do
      it "returns proper preferred_languages_array" do
        user = nil

        sidekiq_perform_enqueued_jobs do
          user = create(:user, email: "ben@hello.jp")
        end

        expect(user.reload.preferred_languages_array).to eq(%w[en ja])
      end

      it "returns a correct array for language settings" do
        language_settings = { estimated_default_language: "en", preferred_languages: %w[en ru it] }
        user = build(:user, language_settings: language_settings)
        expect(user.preferred_languages_array).to eq(%w[en ru it])
      end
    end
  end

  context "when callbacks are triggered after save" do
    describe "subscribing to mailchimp newsletter" do
      let(:user) { build(:user) }

      it "enqueues SubscribeToMailchimpNewsletterWorker" do
        sidekiq_assert_enqueued_with(job: Users::SubscribeToMailchimpNewsletterWorker, args: user.id) do
          user.save
        end
      end

      it "does not enqueue without an email" do
        sidekiq_assert_no_enqueued_jobs(only: Users::SubscribeToMailchimpNewsletterWorker) do
          user.update(email: "")
        end
      end

      it "does not enqueue with an invalid email" do
        sidekiq_assert_no_enqueued_jobs(only: Users::SubscribeToMailchimpNewsletterWorker) do
          user.update(email: "foobar")
        end
      end

      it "does not enqueue with an unconfirmed email" do
        sidekiq_assert_no_enqueued_jobs(only: Users::SubscribeToMailchimpNewsletterWorker) do
          user.update(unconfirmed_email: "bob@bob.com", confirmation_sent_at: Time.current)
        end
      end

      it "does not enqueue with a non-registered user" do
        sidekiq_assert_no_enqueued_jobs(only: Users::SubscribeToMailchimpNewsletterWorker) do
          user.update(registered: false)
        end
      end

      it "does not enqueue when the email address or subscription status has not changed" do
        # The trait replaces the method with a dummy, but we need the actual method for this test.
        user = described_class.find(create(:user, :ignore_mailchimp_subscribe_callback).id)

        sidekiq_assert_no_enqueued_jobs(only: Users::SubscribeToMailchimpNewsletterWorker) do
          user.update(website_url: "http://example.com")
        end
      end
    end

    describe "#conditionally_resave_articles" do
      let!(:user) { create(:user) }

      it "enqueues resave articles job when changing username" do
        sidekiq_assert_enqueued_with(
          job: Users::ResaveArticlesWorker,
          args: [user.id],
          queue: "medium_priority",
        ) do
          user.username = "#{user.username} changed"
          user.save
        end
      end

      it "enqueues resave articles job when changing name" do
        sidekiq_assert_enqueued_with(
          job: Users::ResaveArticlesWorker,
          args: [user.id],
          queue: "medium_priority",
        ) do
          user.name = "#{user.name} changed"
          user.save
        end
      end

      it "enqueues resave articles job when changing summary" do
        sidekiq_assert_enqueued_with(
          job: Users::ResaveArticlesWorker,
          args: [user.id],
          queue: "medium_priority",
        ) do
          user.summary = "#{user.summary} changed"
          user.save
        end
      end

      it "enqueues resave articles job when changing bg_color_hex" do
        sidekiq_assert_enqueued_with(
          job: Users::ResaveArticlesWorker,
          args: [user.id],
          queue: "medium_priority",
        ) do
          user.bg_color_hex = "#12345F"
          user.save
        end
      end

      it "enqueues resave articles job when changing text_color_hex" do
        sidekiq_assert_enqueued_with(
          job: Users::ResaveArticlesWorker,
          args: [user.id],
          queue: "medium_priority",
        ) do
          user.text_color_hex = "#FA345E"
          user.save
        end
      end

      it "enqueues resave articles job when changing profile_image" do
        sidekiq_assert_enqueued_with(
          job: Users::ResaveArticlesWorker,
          args: [user.id],
          queue: "medium_priority",
        ) do
          user.profile_image = "https://fakeimg.pl/300/"
          user.save
        end
      end

      Authentication::Providers.username_fields.each do |username_field|
        it "enqueues resave articles job when changing #{username_field}" do
          sidekiq_assert_enqueued_with(
            job: Users::ResaveArticlesWorker,
            args: [user.id],
            queue: "medium_priority",
          ) do
            user.assign_attributes(username_field => "greatnewusername")
            user.save
          end
        end

        it "doesn't enqueue resave articles job when changing #{username_field} for a banned user" do
          banned_user = create(:user, :banned)

          expect do
            banned_user.assign_attributes(username_field => "greatnewusername")
            banned_user.save
          end.not_to change(Users::ResaveArticlesWorker.jobs, :size)
        end
      end
    end
  end

  describe "user registration", vcr: { cassette_name: "fastly_sloan" } do
    let(:user) { create(:user) }

    before do
      omniauth_mock_providers_payload
    end

    Authentication::Providers.available.each do |provider_name|
      it "finds user by email and assigns identity to that if exists for #{provider_name}" do
        OmniAuth.config.mock_auth[provider_name].info.email = user.email

        new_user = user_from_authorization_service(provider_name)
        expect(new_user.id).to eq(user.id)
      end

      it "assigns random username if username is taken on registration for #{provider_name}" do
        OmniAuth.config.mock_auth[provider_name].info.nickname = user.username
        OmniAuth.config.mock_auth[provider_name].info.first_name = user.username

        new_user = user_from_authorization_service(provider_name)

        expect(new_user.persisted?).to be(true)
        expect(new_user.username).not_to eq(user.username)
      end

      it "assigns signup_cta_variant to state param if new user for #{provider_name}" do
        new_user = user_from_authorization_service(provider_name, nil, "hey-hey-hey")
        expect(new_user.signup_cta_variant).to eq("hey-hey-hey")
      end

      it "does not assign signup_cta_variant to non-new users for #{provider_name}" do
        returning_user = create(:user, signup_cta_variant: nil)
        new_user = user_from_authorization_service(provider_name, returning_user, "hey-hey-hey")
        expect(new_user.signup_cta_variant).to be(nil)
      end

      it "assigns proper social username based on authentication for #{provider_name}" do
        mock_username(provider_name, "valid_username")
        new_user = user_from_authorization_service(provider_name)

        case provider_name
        when :apple
          expect(new_user.username).to match(/valid_username_\w+/)
        when :facebook
          expect(new_user.username).to match(/fname_lname_\S*\z/)
        else
          expect(new_user.username).to eq("valid_username")
        end
      end

      it "marks registered_at for newly registered user" do
        new_user = user_from_authorization_service(provider_name, nil, "navbar_basic")
        expect(new_user.registered_at).not_to be nil
      end

      it "assigns modified username if the username is invalid for #{provider_name}" do
        mock_username(provider_name, "invalid.username")
        new_user = user_from_authorization_service(provider_name)

        case provider_name
        when :apple
          expect(new_user.username).to match(/invalidusername_\w+/)
        when :facebook
          expect(new_user.username).to match(/fname_lname_\S*\z/)
        else
          expect(new_user.username).to eq("invalidusername")
        end
      end

      it "serializes the authentication payload for #{provider_name}" do
        new_user = user_from_authorization_service(provider_name)

        identity = new_user.identities.last
        expect(identity.auth_data_dump.provider).to eq(identity.provider)
      end

      it "does not allow previously banished users to sign up again for #{provider_name}" do
        banished_name = "SpammyMcSpamface"
        mock_username(provider_name, banished_name)

        create(:banished_user, username: provider_username(provider_name))
        expect do
          user_from_authorization_service(provider_name, nil, "navbar_basic")
        end.to raise_error(ActiveRecord::RecordInvalid, /Username has been banished./)
      end
    end

    it "persists extracts relevant identity data from new twitter user" do
      new_user = user_from_authorization_service(:twitter, nil, "navbar_basic")
      expect(new_user.twitter_followers_count).to eq(100)
      expect(new_user.twitter_created_at).to be_kind_of(ActiveSupport::TimeWithZone)
    end

    it "assigns multiple identities to the same user", :aggregate_failures, vcr: { cassette_name: "fastly_sloan" } do
      providers = Authentication::Providers.available

      users = []
      Authentication::Providers.available.each do |provider_name|
        OmniAuth.config.mock_auth[provider_name].info.email = "person1@example.com"

        users.append(user_from_authorization_service(provider_name))
      end

      expect(users.uniq.first.identities.count).to eq(providers.length)
    end
  end

  it "does not allow an existing user to change their name to a banished one" do
    banished_name = "SpammyMcSpamface"
    create(:banished_user, username: banished_name)
    user = create(:user)

    user.update(username: banished_name)
    expect(user.errors.full_messages).to include("Username has been banished.")
  end

  describe "#follow and #all_follows" do
    it "follows users" do
      expect do
        user.follow(create(:user))
      end.to change(user.all_follows, :size).by(1)
    end
  end

  describe "#moderator_for_tags" do
    let(:tags) { create_list(:tag, 2) }

    it "lists tags user moderates" do
      user.add_role(:tag_moderator, tags.first)

      expect(user.moderator_for_tags).to include(tags.first.name)
      expect(user.moderator_for_tags).not_to include(tags.last.name)
    end

    it "returns empty array if no tags moderated" do
      expect(user.moderator_for_tags).to be_empty
    end
  end

  describe "#followed_articles" do
    let!(:another_user) { create(:user) }
    let!(:articles) { create_list(:article, 2, user: another_user) }

    before do
      user.follow(another_user)
    end

    it "returns all articles following" do
      expect(user.followed_articles.size).to eq(articles.size)
    end

    it "returns segment of articles if limit is passed" do
      expect(user.followed_articles.limit(1).size).to eq(articles.size - 1)
    end
  end

  describe "theming properties" do
    it "creates proper body class with defaults" do
      classes = "default sans-serif-article-body trusted-status-#{user.trusted} #{user.config_navbar}-navbar-config"
      expect(user.decorate.config_body_class).to eq(classes)
    end

    it "determines dark theme if night theme" do
      user.config_theme = "night_theme"
      expect(user.decorate.dark_theme?).to eq(true)
    end

    it "determines dark theme if ten x hacker" do
      user.config_theme = "ten_x_hacker_theme"
      expect(user.decorate.dark_theme?).to eq(true)
    end

    it "determines not dark theme if not one of the dark themes" do
      user.config_theme = "default"
      expect(user.decorate.dark_theme?).to eq(false)
    end

    it "creates proper body class with sans serif config" do
      user.config_font = "sans_serif"

      classes = "default sans-serif-article-body trusted-status-#{user.trusted} #{user.config_navbar}-navbar-config"
      expect(user.decorate.config_body_class).to eq(classes)
    end

    it "creates proper body class with open dyslexic config" do
      user.config_font = "open_dyslexic"

      classes = "default open-dyslexic-article-body trusted-status-#{user.trusted} #{user.config_navbar}-navbar-config"
      expect(user.decorate.config_body_class).to eq(classes)
    end

    it "creates proper body class with night theme" do
      user.config_theme = "night_theme"

      classes = "night-theme sans-serif-article-body trusted-status-#{user.trusted} #{user.config_navbar}-navbar-config"
      expect(user.decorate.config_body_class).to eq(classes)
    end

    it "creates proper body class with pink theme" do
      user.config_theme = "pink_theme"

      classes = "pink-theme sans-serif-article-body trusted-status-#{user.trusted} #{user.config_navbar}-navbar-config"
      expect(user.decorate.config_body_class).to eq(classes)
    end
  end

  describe "#calculate_score" do
    it "calculates a score" do
      create(:article, featured: true, user: user)

      user.calculate_score
      expect(user.score).to be_positive
    end
  end

  describe "cache counts" do
    it "has an accurate tag follow count" do
      tag = create(:tag)
      user.follow(tag)
      expect(user.reload.following_tags_count).to eq(1)
    end

    it "has an accurate user follow count" do
      user.follow(other_user)
      expect(user.reload.following_users_count).to eq(1)
    end

    it "has an accurate organization follow count" do
      user.follow(org)
      expect(user.reload.following_orgs_count).to eq(1)
    end

    it "returns cached ids of articles that have been saved to their readinglist" do
      article = create(:article)
      article2 = create(:article)
      create(:reading_reaction, user: user, reactable: article)
      create(:reading_reaction, user: user, reactable: article2)

      expect(user.cached_reading_list_article_ids).to eq([article2.id, article.id])
    end
  end

  describe "#org_admin?" do
    it "recognizes an org admin" do
      create(:organization_membership, user: user, organization: org, type_of_user: "admin")
      expect(user.org_admin?(org)).to be(true)
    end

    it "forbids an incorrect org admin" do
      other_org = create(:organization)
      create(:organization_membership, user: user, organization: org, type_of_user: "admin")
      expect(user.org_admin?(other_org)).to be(false)
      expect(other_user.org_admin?(org)).to be(false)
    end

    it "returns false if nil is given" do
      expect(user.org_admin?(nil)).to be(false)
    end
  end

  describe "#pro?" do
    it "returns false if the user is not a pro" do
      expect(user.pro?).to be(false)
    end

    it "returns true if the user has the pro role" do
      user.add_role(:pro)
      expect(user.pro?).to be(true)
    end
  end

  describe "#enough_credits?" do
    it "returns false if the user has less unspent credits than neeed" do
      expect(user.enough_credits?(1)).to be(false)
    end

    it "returns true if the user has the exact amount of unspent credits" do
      create(:credit, user: user, spent: false)
      expect(user.enough_credits?(1)).to be(true)
    end

    it "returns true if the user has more unspent credits than needed" do
      create_list(:credit, 2, user: user, spent: false)
      expect(user.enough_credits?(1)).to be(true)
    end
  end

  describe "#receives_follower_email_notifications?" do
    it "returns false if user has no email" do
      user.assign_attributes(email: nil)
      expect(user.receives_follower_email_notifications?).to be(false)
    end

    it "returns false if user opted out from follower notifications" do
      user.assign_attributes(email_follower_notifications: false)
      expect(user.receives_follower_email_notifications?).to be(false)
    end

    it "returns true if user opted in from follower notifications and has an email" do
      user.assign_attributes(email_follower_notifications: true)
      expect(user.receives_follower_email_notifications?).to be(true)
    end
  end

  describe ".dev_account" do
    it "returns nil if the account does not exist" do
      expect(described_class.dev_account).to be_nil
    end

    it "returns the user if the account exists" do
      allow(SiteConfig).to receive(:staff_user_id).and_return(user.id)

      expect(described_class.dev_account).to eq(user)
    end
  end

  describe ".mascot_account" do
    it "returns nil if the account does not exist" do
      expect(described_class.mascot_account).to be_nil
    end

    it "returns the user if the account exists" do
      allow(SiteConfig).to receive(:mascot_user_id).and_return(user.id)

      expect(described_class.mascot_account).to eq(user)
    end
  end

  describe "#authenticated_through?" do
    let(:provider) { Authentication::Providers.available.first }

    it "returns false if provider is not known" do
      expect(user.authenticated_through?(:unknown)).to be(false)
    end

    it "returns false if provider is not enabled" do
      providers = Authentication::Providers.available - [provider]
      allow(Authentication::Providers).to receive(:enabled).and_return(providers)

      expect(user.authenticated_through?(provider)).to be(false)
    end

    it "returns false if the user has no related identity" do
      expect(user.authenticated_through?(provider)).to be(false)
    end

    it "returns true if the user has related identity" do
      user = create(:user, :with_identity, identities: [provider])
      expect(user.authenticated_through?(provider)).to be(true)
    end
  end

  describe "#authenticated_with_all_providers?" do
    let(:provider) { Authentication::Providers.available.first }

    it "returns false if the user has no related identity" do
      expect(user.authenticated_with_all_providers?).to be(false)
    end

    it "returns false if the user is missing any of the identities" do
      providers = Authentication::Providers.available - [provider]
      user = create(:user, :with_identity, identities: providers)

      expect(user.authenticated_with_all_providers?).to be(false)
    end

    it "returns true if the user has all the enabled providers" do
      allow(SiteConfig).to receive(:authentication_providers).and_return(Authentication::Providers.available)

      user = create(:user, :with_identity)

      expect(user.authenticated_with_all_providers?).to be(true)
    end
  end

  describe "profiles" do
    before do
      create(:profile_field, label: "Available for")
      create(:profile_field, label: "Brand Color 1")
      Profile.refresh_attributes!
    end

    it "automatically creates a profile for new users", :aggregate_failures do
      user = create(:user)
      expect(user.profile).to be_present
      expect(user.profile).to respond_to(:available_for)
    end

    it "propagates changes of unmapped attributes to the profile model", :aggregate_failures do
      expect do
        user.update(available_for: "profile migrations")
      end.to change { user.profile.reload.available_for }.from(nil).to("profile migrations")

      # Changes were also persisted in the users table
      expect(user.reload.available_for).to eq "profile migrations"
    end

    it "propagates changes of mapped attributes to the profile model", :aggregate_failures do
      expect do
        user.update(bg_color_hex: "#abcdef")
      end.to change { user.profile.reload.brand_color1 }.to("#abcdef")

      # Changes were also persisted in the users table
      expect(user.reload.bg_color_hex).to eq "#abcdef"
    end
  end
end
