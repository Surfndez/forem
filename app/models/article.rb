class Article < ApplicationRecord
  include CloudinaryHelper
  include ActionView::Helpers
  include Storext.model
  include Reactable
  include Searchable
  include UserSubscriptionSourceable

  SEARCH_SERIALIZER = Search::ArticleSerializer
  SEARCH_CLASS = Search::FeedContent
  DATA_SYNC_CLASS = DataSync::Elasticsearch::Article

  acts_as_taggable_on :tags
  resourcify

  attr_accessor :publish_under_org
  attr_writer :series

  delegate :name, to: :user, prefix: true
  delegate :username, to: :user, prefix: true

  # touch: true was removed because when an article is updated, the associated collection
  # is touched along with all its articles(including this one). This causes eventually a deadlock.
  belongs_to :collection, optional: true

  belongs_to :organization, optional: true
  belongs_to :user

  counter_culture :user
  counter_culture :organization

  has_many :buffer_updates, dependent: :destroy
  has_many :comments, as: :commentable, inverse_of: :commentable, dependent: :nullify
  has_many :html_variant_successes, dependent: :nullify
  has_many :html_variant_trials, dependent: :nullify
  has_many :notification_subscriptions, as: :notifiable, inverse_of: :notifiable, dependent: :destroy
  has_many :notifications, as: :notifiable, inverse_of: :notifiable, dependent: :delete_all
  has_many :page_views, dependent: :destroy
  has_many :polls, dependent: :destroy
  has_many :profile_pins, as: :pinnable, inverse_of: :pinnable, dependent: :destroy
  has_many :rating_votes, dependent: :destroy
  has_many :top_comments,
           lambda {
             where(comments: { score: 11.. }, ancestry: nil, hidden_by_commentable_user: false, deleted: false)
               .order("comments.score" => :desc)
           },
           as: :commentable,
           inverse_of: :commentable,
           class_name: "Comment"

  validates :body_markdown, length: { minimum: 0, allow_nil: false }, uniqueness: { scope: %i[user_id title] }
  validates :cached_tag_list, length: { maximum: 126 }
  validates :canonical_url, uniqueness: { allow_nil: true }
  validates :canonical_url, url: { allow_blank: true, no_local: true, schemes: %w[https http] }
  validates :feed_source_url, uniqueness: { allow_nil: true }
  validates :feed_source_url, url: { allow_blank: true, no_local: true, schemes: %w[https http] }
  validates :main_image, url: { allow_blank: true, schemes: %w[https http] }
  validates :main_image_background_hex_color, format: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/
  validates :slug, presence: { if: :published? }, format: /\A[0-9a-z\-_]*\z/
  validates :slug, uniqueness: { scope: :user_id }
  validates :title, presence: true, length: { maximum: 128 }
  validates :user_id, presence: true
  validates :video, url: { allow_blank: true, schemes: %w[https http] }
  validates :video_closed_caption_track_url, url: { allow_blank: true, schemes: ["https"] }
  validates :video_source_url, url: { allow_blank: true, schemes: ["https"] }
  validates :video_source_url, url: { allow_blank: true, schemes: ["https"] }
  validates :video_state, inclusion: { in: %w[PROGRESSING COMPLETED] }, allow_nil: true
  validates :video_thumbnail_url, url: { allow_blank: true, schemes: %w[https http] }

  validate :canonical_url_must_not_have_spaces
  validate :past_or_present_date
  validate :validate_collection_permission
  validate :validate_tag
  validate :validate_video

  before_validation :evaluate_markdown, :create_slug
  before_save :update_cached_user
  before_save :set_all_dates
  before_save :clean_data
  before_save :calculate_base_scores
  before_save :fetch_video_duration
  before_save :set_caches
  before_create :create_password
  before_destroy :before_destroy_actions, prepend: true

  after_save :bust_cache, :detect_human_language
  after_save :notify_slack_channel_about_publication

  after_update_commit :update_notifications, if: proc { |article|
                                                   article.notifications.any? && !article.saved_changes.empty?
                                                 }
  after_commit :async_score_calc, :update_main_image_background_hex, :touch_collection, on: %i[create update]
  after_commit :index_to_elasticsearch, on: %i[create update]
  after_commit :sync_related_elasticsearch_docs, on: %i[create update]
  after_commit :remove_from_elasticsearch, on: [:destroy]

  serialize :cached_user
  serialize :cached_organization

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }

  scope :admin_published_with, lambda { |tag_name|
    published
      .where(user_id: SiteConfig.staff_user_id)
      .order(published_at: :desc)
      .tagged_with(tag_name)
  }

  scope :user_published_with, lambda { |user_id, tag_name|
    published
      .where(user_id: user_id)
      .order(published_at: :desc)
      .tagged_with(tag_name)
  }

  scope :cached_tagged_with, ->(tag) { where("cached_tag_list ~* ?", "^#{tag},| #{tag},|, #{tag}$|^#{tag}$") }

  scope :cached_tagged_by_approval_with, ->(tag) { cached_tagged_with(tag).where(approved: true) }

  scope :active_help, lambda {
    published
      .cached_tagged_with("help")
      .order(created_at: :desc)
      .where("published_at > ? AND comments_count < ? AND score > ?", 12.hours.ago, 6, -4)
  }

  scope :limited_column_select, lambda {
    select(:path, :title, :id, :published,
           :comments_count, :public_reactions_count, :cached_tag_list,
           :main_image, :main_image_background_hex_color, :updated_at, :slug,
           :video, :user_id, :organization_id, :video_source_url, :video_code,
           :video_thumbnail_url, :video_closed_caption_track_url, :language,
           :experience_level_rating, :experience_level_rating_distribution, :cached_user, :cached_organization,
           :published_at, :crossposted_at, :boost_states, :description, :reading_time, :video_duration_in_seconds,
           :last_comment_at)
  }

  scope :limited_columns_internal_select, lambda {
    select(:path, :title, :id, :featured, :approved, :published,
           :comments_count, :public_reactions_count, :cached_tag_list,
           :main_image, :main_image_background_hex_color, :updated_at, :boost_states,
           :video, :user_id, :organization_id, :video_source_url, :video_code,
           :video_thumbnail_url, :video_closed_caption_track_url, :social_image,
           :published_from_feed, :crossposted_at, :published_at, :featured_number,
           :last_buffered, :facebook_last_buffered, :created_at, :body_markdown,
           :email_digest_eligible, :processed_html, :second_user_id, :third_user_id)
  }

  scope :boosted_via_additional_articles, lambda {
    where("boost_states ->> 'boosted_additional_articles' = 'true'")
  }

  scope :boosted_via_dev_digest_email, lambda {
    where("boost_states ->> 'boosted_dev_digest_email' = 'true'")
  }

  scope :sorting, lambda { |value|
    value ||= "creation-desc"
    kind, dir = value.split("-")

    dir = "desc" unless %w[asc desc].include?(dir)

    column =
      case kind
      when "creation"  then :created_at
      when "views"     then :page_views_count
      when "reactions" then :public_reactions_count
      when "comments"  then :comments_count
      when "published" then :published_at
      else
        :created_at
      end

    order(column => dir.to_sym)
  }

  scope :feed, lambda {
                 published.includes(:taggings)
                   .select(
                     :id, :published_at, :processed_html, :user_id, :organization_id, :title, :path, :cached_tag_list
                   )
               }

  scope :with_video, lambda {
                       published
                         .where.not(video: [nil, ""])
                         .where.not(video_thumbnail_url: [nil, ""])
                         .where("score > ?", -4)
                     }

  scope :eager_load_serialized_data, -> { includes(:user, :organization, :tags) }

  store_attributes :boost_states do
    boosted_additional_articles Boolean, default: false
    boosted_dev_digest_email Boolean, default: false
    boosted_additional_tags String, default: ""
  end

  def self.active_threads(tags = ["discuss"], time_ago = nil, number = 10)
    stories = published.limit(number)
    stories = if time_ago == "latest"
                stories.order(published_at: :desc).where("score > ?", -5)
              elsif time_ago
                stories.order(comments_count: :desc)
                  .where("published_at > ? AND score > ?", time_ago, -5)
              else
                stories.order(last_comment_at: :desc)
                  .where("published_at > ? AND score > ?", (tags.present? ? 5 : 2).days.ago, -5)
              end
    stories = tags.size == 1 ? stories.cached_tagged_with(tags.first) : stories.tagged_with(tags)
    stories.pluck(:path, :title, :comments_count, :created_at)
  end

  def self.seo_boostable(tag = nil, time_ago = 18.days.ago)
    # Time ago sometimes returns this phrase instead of a date
    time_ago = 5.days.ago if time_ago == "latest"

    # Time ago sometimes is given as nil and should then be the default. I know, sloppy.
    time_ago = 75.days.ago if time_ago.nil?

    relation = Article.published
      .order(organic_page_views_past_month_count: :desc)
      .where("score > ?", 8)
      .where("published_at > ?", time_ago)
      .limit(20)

    fields = %i[path title comments_count created_at]
    if tag
      relation.cached_tagged_with(tag).pluck(*fields)
    else
      relation.pluck(*fields)
    end
  end

  def self.search_optimized(tag = nil)
    relation = Article.published
      .order(updated_at: :desc)
      .where.not(search_optimized_title_preamble: nil)
      .limit(20)

    fields = %i[path search_optimized_title_preamble comments_count created_at]
    if tag
      relation.cached_tagged_with(tag).pluck(*fields)
    else
      relation.pluck(*fields)
    end
  end

  def search_id
    "article_#{id}"
  end

  def processed_description
    text_portion = body_text.present? ? body_text[0..100].tr("\n", " ").strip.to_s : ""
    text_portion = "#{text_portion.strip}..." if body_text.size > 100
    return "A post by #{user.name}" if text_portion.blank?

    text_portion.strip
  end

  def body_text
    ActionView::Base.full_sanitizer.sanitize(processed_html)[0..7000]
  end

  def touch_by_reaction
    async_score_calc
    index_to_elasticsearch
  end

  def comments_blob
    return "" if comments_count.zero?

    ActionView::Base.full_sanitizer.sanitize(comments.pluck(:body_markdown).join(" "))[0..2200]
  end

  def username
    return organization.slug if organization

    user.username
  end

  def current_state_path
    published ? "/#{username}/#{slug}" : "/#{username}/#{slug}?preview=#{password}"
  end

  def has_frontmatter?
    fixed_body_markdown = MarkdownFixer.fix_all(body_markdown)
    begin
      parsed = FrontMatterParser::Parser.new(:md).call(fixed_body_markdown)
      parsed.front_matter["title"].present?
    rescue Psych::SyntaxError, Psych::DisallowedClass
      # if frontmatter is invalid, still render editor with errors instead of 500ing
      true
    end
  end

  def class_name
    self.class.name
  end

  def flare_tag
    @flare_tag ||= FlareTag.new(self).tag_hash
  end

  def edited?
    edited_at.present?
  end

  def readable_edit_date
    return unless edited?

    if edited_at.year == Time.current.year
      edited_at.strftime("%b %e")
    else
      edited_at.strftime("%b %e '%y")
    end
  end

  def readable_publish_date
    relevant_date = displayable_published_at
    if relevant_date && relevant_date.year == Time.current.year
      relevant_date&.strftime("%b %e")
    else
      relevant_date&.strftime("%b %e '%y")
    end
  end

  def published_timestamp
    return "" unless published
    return "" unless crossposted_at || published_at

    displayable_published_at.utc.iso8601
  end

  def displayable_published_at
    crossposted_at.presence || published_at
  end

  def series
    # name of series article is part of
    collection&.slug
  end

  def all_series
    # all series names
    user&.collections&.pluck(:slug)
  end

  def cloudinary_video_url
    return if video_thumbnail_url.blank?

    Images::Optimizer.call(video_thumbnail_url, width: 880, quality: 80)
  end

  def video_duration_in_minutes
    duration = ActiveSupport::Duration.build(video_duration_in_seconds.to_i).parts
    minutes_and_seconds = format("%<minutes>02d:%<seconds>02d", duration)
    return minutes_and_seconds if duration[:hours] < 1

    "#{duration[:hours]}:#{minutes_and_seconds}"
  end

  def update_score
    new_score = reactions.sum(:points) + Reaction.where(reactable_id: user_id, reactable_type: "User").sum(:points)
    update_columns(score: new_score,
                   comment_score: comments.sum(:score),
                   hotness_score: BlackBox.article_hotness_score(self),
                   spaminess_rating: BlackBox.calculate_spaminess(self))
  end

  private

  def search_score
    comments_score = (comments_count * 3).to_i
    partial_score = (comments_score + public_reactions_count.to_i * 300 * user.reputation_modifier * score.to_i)
    calculated_score = hotness_score.to_i + partial_score
    calculated_score.to_i
  end

  def tag_keywords_for_search
    tags.pluck(:keywords_for_search).join
  end

  def calculated_path
    if organization
      "/#{organization.slug}/#{slug}"
    else
      "/#{username}/#{slug}"
    end
  end

  def set_caches
    return unless user

    self.cached_user_name = user_name
    self.cached_user_username = user_username
    self.path = calculated_path
  end

  def evaluate_markdown
    fixed_body_markdown = MarkdownFixer.fix_all(body_markdown || "")
    parsed = FrontMatterParser::Parser.new(:md).call(fixed_body_markdown)
    parsed_markdown = MarkdownParser.new(parsed.content, source: self, user: user)
    self.reading_time = parsed_markdown.calculate_reading_time
    self.processed_html = parsed_markdown.finalize

    if parsed.front_matter.any?
      evaluate_front_matter(parsed.front_matter)
    elsif tag_list.any?
      set_tag_list(tag_list)
    end

    self.description = processed_description if description.blank?
  rescue StandardError => e
    errors[:base] << ErrorMessageCleaner.new(e.message).clean
  end

  def set_tag_list(tags)
    self.tag_list = [] # overwrite any existing tag with those from the front matter
    tag_list.add(tags, parse: true)
    self.tag_list = tag_list.map { |tag| Tag.find_preferred_alias_for(tag) }
  end

  def update_main_image_background_hex
    return unless saved_changes.key?("main_image")
    return if main_image.blank? || main_image_background_hex_color != "#dddddd"

    Articles::UpdateMainImageBackgroundHexWorker.perform_async(id)
  end

  def detect_human_language
    return if language.present?

    update_column(:language, LanguageDetector.new(self).detect)
  end

  def async_score_calc
    return if !published? || destroyed?

    Articles::ScoreCalcWorker.perform_async(id)
  end

  def fetch_video_duration
    if video.present? && video_duration_in_seconds.zero?
      url = video_source_url.gsub(".m3u8", "1351620000001-200015_hls_v4.m3u8")
      duration = 0
      HTTParty.get(url).body.split("#EXTINF:").each do |chunk|
        duration += chunk.split(",")[0].to_f
      end
      self.video_duration_in_seconds = duration
      duration
    end
  rescue StandardError => e
    Rails.logger.error(e)
  end

  def update_notifications
    Notification.update_notifications(self, "Published")
  end

  def before_destroy_actions
    bust_cache
    article_ids = user.article_ids.dup
    if organization
      organization.touch(:last_article_at)
      article_ids.concat organization.article_ids
    end
    # perform busting cache in chunks in case there're a lot of articles
    (article_ids.uniq.sort - [id]).each_slice(10) do |ids|
      Articles::BustMultipleCachesWorker.perform_async(ids)
    end
  end

  def evaluate_front_matter(front_matter)
    self.title = front_matter["title"] if front_matter["title"].present?
    set_tag_list(front_matter["tags"]) if front_matter["tags"].present?
    self.published = front_matter["published"] if %w[true false].include?(front_matter["published"].to_s)
    self.published_at = parse_date(front_matter["date"]) if published
    self.main_image = determine_image(front_matter)
    self.canonical_url = front_matter["canonical_url"] if front_matter["canonical_url"].present?

    update_description = front_matter["description"].present? || front_matter["title"].present?
    self.description = front_matter["description"] if update_description

    self.collection_id = nil if front_matter["title"].present?
    self.collection_id = Collection.find_series(front_matter["series"], user).id if front_matter["series"].present?
  end

  def determine_image(front_matter)
    # In order to clear out the cover_image, we check for the key in the front_matter.
    # If the key exists, we use the value from it (a url or `nil`).
    # Otherwise, we fall back to the main_image on the article.
    has_cover_image = front_matter.include?("cover_image")

    if has_cover_image && (front_matter["cover_image"].present? || main_image)
      front_matter["cover_image"]
    else
      main_image
    end
  end

  def parse_date(date)
    # once published_at exist, it can not be adjusted
    published_at || date || Time.current
  end

  def validate_tag
    # remove adjusted tags
    remove_tag_adjustments_from_tag_list
    add_tag_adjustments_to_tag_list

    # check there are not too many tags
    return errors.add(:tag_list, "exceed the maximum of 4 tags") if tag_list.size > 4

    # check tags names aren't too long and don't contain non alphabet characters
    tag_list.each do |tag|
      new_tag = Tag.new(name: tag)
      new_tag.validate_name
      new_tag.errors.messages[:name].each { |message| errors.add(:tag, "\"#{tag}\" #{message}") }
    end
  end

  def remove_tag_adjustments_from_tag_list
    tags_to_remove = TagAdjustment.where(article_id: id, adjustment_type: "removal",
                                         status: "committed").pluck(:tag_name)
    tag_list.remove(tags_to_remove, parse: true) if tags_to_remove.present?
  end

  def add_tag_adjustments_to_tag_list
    tags_to_add = TagAdjustment.where(article_id: id, adjustment_type: "addition", status: "committed").pluck(:tag_name)
    return if tags_to_add.blank?

    tag_list.add(tags_to_add, parse: true)
    self.tag_list = tag_list.map { |tag| Tag.find_preferred_alias_for(tag) }
  end

  def validate_video
    if published && video_state == "PROGRESSING"
      return errors.add(:published,
                        "cannot be set to true if video is still processing")
    end

    return unless video.present? && user.created_at > 2.weeks.ago

    errors.add(:video, "cannot be added by member without permission")
  end

  def validate_collection_permission
    return unless collection && collection.user_id != user_id

    errors.add(:collection_id, "must be one you have permission to post to")
  end

  def past_or_present_date
    return unless published_at && published_at > Time.current

    errors.add(:date_time, "must be entered in DD/MM/YYYY format with current or past date")
  end

  def canonical_url_must_not_have_spaces
    return unless canonical_url.to_s.match?(/[[:space:]]/)

    errors.add(:canonical_url, "must not have spaces")
  end

  def create_slug
    if slug.blank? && title.present? && !published
      self.slug = title_to_slug + "-temp-slug-#{rand(10_000_000)}"
    elsif should_generate_final_slug?
      self.slug = title_to_slug
    end
  end

  def should_generate_final_slug?
    (title && published && slug.blank?) ||
      (title && published && slug.include?("-temp-slug-"))
  end

  def create_password
    return if password.present?

    self.password = SecureRandom.hex(60)
  end

  def update_cached_user
    if organization
      self.cached_organization = Articles::CachedEntity.from_object(organization)
    end

    return unless user

    self.cached_user = Articles::CachedEntity.from_object(user)
  end

  def set_all_dates
    set_published_date
    set_featured_number
    set_crossposted_at
    set_last_comment_at
    set_nth_published_at
  end

  def set_published_date
    self.published_at = Time.current if published && published_at.blank?
  end

  def set_featured_number
    self.featured_number = Time.current.to_i if featured_number.blank? && published
  end

  def set_crossposted_at
    self.crossposted_at = Time.current if published && crossposted_at.blank? && published_from_feed
  end

  def set_last_comment_at
    return unless published_at.present? && last_comment_at == "Sun, 01 Jan 2017 05:00:00 UTC +00:00"

    self.last_comment_at = published_at
    user.touch(:last_article_at)
    organization&.touch(:last_article_at)
  end

  def set_nth_published_at
    return unless nth_published_by_author.zero? && published

    published_article_ids = user.articles.published.order(published_at: :asc).ids
    index = published_article_ids.index(id)

    self.nth_published_by_author = (index || published_article_ids.size) + 1
  end

  def title_to_slug
    "#{title.to_s.downcase.parameterize.tr('_', '')}-#{rand(100_000).to_s(26)}"
  end

  def clean_data
    self.canonical_url = nil if canonical_url == ""
  end

  def bust_cache
    CacheBuster.bust(path)
    CacheBuster.bust("#{path}?i=i")
    CacheBuster.bust("#{path}?preview=#{password}")
    async_bust
  end

  def calculate_base_scores
    self.hotness_score = 1000 if hotness_score.blank?
    self.spaminess_rating = 0 if new_record?
  end

  def async_bust
    Articles::BustCacheWorker.perform_async(id)
  end

  def touch_collection
    collection.touch if collection && previous_changes.present?
  end

  def notify_slack_channel_about_publication
    Slack::Messengers::ArticlePublished.call(article: self)
  end
end
