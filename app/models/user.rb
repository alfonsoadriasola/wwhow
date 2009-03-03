class User < ActiveRecord::Base

    has_many  :blog_entries
    has_many  :subscriptions
    belongs_to :web_user

    acts_as_mappable :auto_geocode => true
    before_validation_on_update :geocode_address

    def self.find_active
        sqlcmd = %Q{
           SELECT 
           u.id,u.name,count(m.id)
           FROM  users u
          INNER JOIN blog_entries m on u.id =  m.user_id  
          GROUP BY u.id, u.name
          ORDER BY 2 DESC LIMIT 50}
        self.find_by_sql [sqlcmd]
    end

    private
    def self.rate(user)

        ratedMessags, messagesRated, averageRating = 0
        ratedMessages = Rating.count(:conditions =>
                %Q{rateable_type='BlogEntry'
                                 and rateable_id in
                                        (select b.id
                                        from  blog_entries b
                                        where b.user_id = #{user.id} ) } )
        messagesRated = Rating.count(:conditions => "user_id = #{user.id}")
        averageRating = Rating.average(:rating, :conditions => "user_id = #{user.id}")

        ratedMessages = 0 if ratedMessages.nil?
        messagesRated = 0 if messagesRated.nil?
        averageRating = 0 if averageRating.nil?

        averageRating  * ( ratedMessages * 2  + messagesRated )        
    end

    def self.rank(rating)
        case rating
        when 0..199
            "meh"
        when 200..399
            "pretty good"
        when 400..599
            "darn good"
        when 600..799
            "really great"
        when 800..1200
            "wwhow"
        end

    end

    private

    def geocode_address        
        geo=GeoKit::Geocoders::MultiGeocoder.geocode(address)
        errors.add(:address, "Could not Geocode address") unless geo.success
        self.lat, self.lng = geo.lat, geo.lng if geo.success
    end


end