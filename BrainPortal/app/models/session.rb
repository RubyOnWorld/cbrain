
#
# CBRAIN Project
#
# Model for the current session.
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model represeting the current session. The current session object can 
#be accessed using the <b><tt>current_session</tt></b> method of the ApplicationController
#class.
#
#This model is meant to act as a wrapper around the session hash.
#It takes care of updating the values of and performing any logic related 
#to the following attributes of the current session (mainly related
#to the Userfile index page):
#* currently active filters.
#* whether or not pagination is active.
#* current ordering of the Userfile index.
#* whether to view current user's files or all files on the system (*admin* only).
#
#Session attributes can be accessed by calling methods with the attribute name.
#*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
#
#*Note*: this is not a database-backed model.
class Session

  Revision_info="$Id$"

  def initialize(session) #:nodoc:
    @session = session
    @session[:current_filters] ||= []
    @session[:pagination] ||= 'on'
    @session[:order] ||= 'lft'
  end
  
  #Update attributes of the session object based on the incoming request parameters
  #contained in the +params+ hash.
  def update(params)
    filter = Userfile.get_filter_name(params[:search_type], params[:search_term])   
    @session[:current_filters] = [] if params[:search_type] == 'none'
    @session[:current_filters] |= [filter] unless filter.blank?
    @session[:current_filters].delete params[:remove_filter] if params[:remove_filter]
    
    if params[:view_all] && User.find(@session[:user_id]).has_role?(:admin)
      @session[:view_all] = params[:view_all]
    end
    
    if params[:order] && !params[:page]
      @session[:order] = Userfile.set_order(params[:order], @session[:order])
    end
        
    if params[:pagination]
      @session[:pagination] = params[:pagination]
    end
  end
  
  #Is pagination of the Userfile index currently active?
  def paginate?
    @session[:pagination] == 'on'
  end
  
  #Is the current *admin* user viewing all files on the system (or only his/her own)?
  def view_all?
    @session[:view_all] == 'on' && User.find(@session[:user_id]).has_role?(:admin)
  end
  
  #The method_missing method has been redefined to allow for simplified access to session parameters.
  #
  #*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
  def method_missing(key, *args)
    @session[key.to_sym]
  end
  
end
