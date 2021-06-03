module VaccineNotifier
  class User < ApplicationRecord
    belongs_to :state, optional: true
    belongs_to :district, optional: true
    has_many :vaccine_alerts
    attr_accessor :age_range
    before_validation :set_age
    validates_presence_of :full_name, :email, :phone, :age
    validates_presence_of :state, if: Proc.new{|u| u.district.present?}
    validates_presence_of :district, if: Proc.new{|u| u.state.present?}
    validate :validate_search_parameter
    validate :validate_pincode, if: Proc.new{|u| u.pincode}
    validate :validate_duplicate, if: Proc.new{|u| ((u.state.present? && u.district.present?) || u.pincode.present?)}, on: :create
    
    private
      def set_age
        self.age = (age_range == "18P" ? 25 : 50)
      end
      
      def validate_duplicate
        duplicate =
          if pincode.present? 
            User.exists?(email: email, phone: phone, pincode: pincode)
          else
            User.exists?(email: email, phone: phone, state: state, district: district)
          end
        if duplicate
          errors.add(:base, :user_already_registered_for_notification)
          return !duplicate
        end
      end
      
      def validate_search_parameter
        unless (pincode.present? || state.present? || district.present?)
          errors.add(:base, :search_parameters_cant_be_blank)
        else
          errors.add(:base, :search_either_by_pincode_or_place) if (state.present? || district.present?) && pincode.present?
        end
      end
      
      def validate_pincode
        if pincode.length != 6 || pincode.scan(/\d+/).join.length != 6 || validate_postal_code
          errors.add(:pincode, :invalid_pincode)
        end
      end
      
      def validate_postal_code
        begin
          uri = URI.parse("https://api.postalpincode.in/pincode/#{self.pincode}")
          http = Net::HTTP.new(uri.host, uri.port)
          if uri.scheme == "https"
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          request = Net::HTTP::Get.new(uri.request_uri)
          res = http.request(request)
          if res.code == "200"
            response = JSON.parse(res.body).first
            return (response["Status"] == "Error")
          end
        rescue Exception => r
          return false
        end
      end
  end
end
