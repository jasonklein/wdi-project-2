class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable, omniauth_providers: [:facebook]


  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :age, :gender_id, :location, :name, :other, :relationship_status, :role, :profile_attributes, :sent_messages_attributes, :received_messages_attributes, :zipcode, :latitude, :location, :longitude, :gender_interest_ids


  geocoded_by :address
  after_validation :geocode

  has_one :profile, dependent: :destroy
  belongs_to :gender

  has_many :interests
  has_many :gender_interests, through: :interests, source: :gender

  has_many :sent_messages, class_name: 'Message', foreign_key: "sender_id"
  has_many :received_messages, class_name: 'Message', foreign_key: "recipient_id"

  has_many :sent_pings, class_name: 'Ping', foreign_key: "pinger_id", dependent: :destroy
  has_many :received_pings, class_name: 'Ping', foreign_key: "pinged_id", dependent: :destroy
  
  has_many :sent_blocks, class_name: 'Block', foreign_key: "blocker_id", dependent: :destroy
  has_many :received_blocks, class_name: 'Block', foreign_key: "blocked_id", dependent: :destroy

  has_many :sent_tracks, class_name: 'Track', foreign_key: "tracker_id", dependent: :destroy
  has_many :received_tracks, class_name: 'Track', foreign_key: "tracked_id", dependent: :destroy

  accepts_nested_attributes_for :profile
  accepts_nested_attributes_for :sent_messages
  accepts_nested_attributes_for :received_messages


  def self.from_omniauth(data)     
    if user = User.find_by_email(data.info.email)
      user.provider = data.provider
      user.uid = data.uid
      user
    else
      where(data.slice(:provider, :uid)).first_or_create do |user|
        user.provider = data.provider
        user.uid = data.uid
        user.password = Devise.friendly_token[0,20]
        user.name = data.info.name
        user.email = data.info.email
        if data.info.location?  
          user.location = data.info.location
        else
          user.location = "London, England"
        end

        user.gender_id = 5
        
        birthday = data.extra.raw_info.birthday
        user.birthday = Date.strptime(birthday, '%m/%d/%Y')
        user.role = "new"
      end

    end
  end


  def age
    now = Time.now.utc.to_date
    now.year - birthday.year - (birthday.to_date.change(:year => now.year) > now ? 1 : 0)
  end

  def messages
    sent_ids = Message.where(sender_id: self.id, sender_readability: true)
    received_ids = Message.where(recipient_id: self.id, recipient_readability: true)
    ids = sent_ids + received_ids
    Message.where(id: ids)
  end

  def unviewed_messages
    self.received_messages.unviewed
  end

  def mark_unviewed_messages_viewed
    self.unviewed_messages.each do |message|
      message.update_attributes(viewed: true)
    end
  end

  def pings
    pinged_ids = Ping.where(pinged_id: self.id)
    pinger_ids = Ping.where(pinger_id: self.id)
    ids = pinged_ids + pinger_ids
    Ping.where(id: ids)
  end

  def unviewed_pings
    self.received_pings.unviewed
  end

  def mark_unviewed_pings_viewed
    self.unviewed_pings.each do |ping|
      ping.update_attributes(viewed: true)
    end
  end

  def role?(role)
    self.role.to_s == role.to_s
  end

  def address
    if zipcode
      zipcode + " " + location
    else
      location
    end
  end
  
  scope :without_user, lambda{|user| user ? {:conditions => ["id != ?", user.id]} : {} }


  scope :people_who_would_be_interested_in_me, lambda {|current_user| select{|user| user.gender_interest_ids.include? current_user.gender_id}}

  # scope :people_i_would_be_interested_in, lambda { where(current_user.gender_interest_ids.include? :gender_id)}

  scope :people_i_would_be_interested_in, lambda {|current_user| where(current_user.gender_interest_ids.include? :gender_id)}

  

end



