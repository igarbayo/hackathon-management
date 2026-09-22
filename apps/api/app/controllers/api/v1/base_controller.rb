module Api
  module V1
    class BaseController < ApplicationController
      before_action :verify_csrf!
    end
  end
end
