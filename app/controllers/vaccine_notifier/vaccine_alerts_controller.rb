require_dependency "vaccine_notifier/application_controller"

module VaccineNotifier
  class VaccineAlertsController < ApplicationController
    before_action :generate_field_data, only: [:subscribe]

    def subscribe
      @states = State.all.map {|s| [s.name.titleize, s.id] }
      @user = User.new
      if request.post?
        @user = User.new(user_params)
        if @user.save
          flash[:notice] = t(:subscription_success)
          redirect_to :root
        end
      end
    end

    def update_districts
      state = State.find_by_id(params[:id])
      @districts = state.districts.order(:name) if state
      respond_to :js
    end

    private
      def generate_field_data
        unless State.exists? && District.exists?
          AppointmentsFinder.new.check_for_data
        end
      end

      def user_params
        params.require(:user).permit(:full_name, :email, :phone, :age_range,
          :pincode, :state_id, :district_id, :fee_type)
      end
  end
end
