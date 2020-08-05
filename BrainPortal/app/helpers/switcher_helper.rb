
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Helper for creating links between related page
# in CBRAIN and NeuroHub
module SwitcherHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  CONTROLLER_MAPPINGS = [
    %w( groups         nh_projects ),
    %w( data_providers nh_storages ),
    %w( users          nh_users    ),
  ]

  # Returns the dashboard path depending on which
  # login page the current user used to log in.
  def login_dashboard_path
    if current_user
      if cbrain_session[:login_page] == 'NeuroHub'
        neurohub_path  # /neurohub -> neurohub_portal#welcome
      else
        home_path      # /home     -> portal#welcome
      end
    end

    # Default is CBRAIN's
    home_path      # /home     -> portal#welcome
  end

  def alternate_dashboard_path
    controller = params[:controller]
    if controller.to_s =~ /^(neurohub_|nh_)/
      home_path
    else
      neurohub_path  # /neurohub -> neurohub_portal#welcome
    end
  end

  # Based on the current controller and action, returns
  # the equivalent page in the other interface. E.g.
  # if the current page is groups#show in CBRAIN, this
  # will return the link to nh_projects#show, and vice
  # versa. If there is no known equivalent page in the
  # other interface, this method returns nil.
  #
  # This method really only makes sense for GET requests.
  def alternate_link_path
    controller = params[:controller] # string
    action     = params[:action]     # string
    id         = params[:id]

    # Method 1: switch the controllers and try to see if
    # the same action exists.
    if pair = CONTROLLER_MAPPINGS.detect { |p| p.include? controller } # find a pair
      alt_cont   = pair.detect { |c| c != controller } # get the other one
      alt_url    = url_for({ :controller => alt_cont, :action => action, :id => id }) rescue nil
      alt_url  ||= url_for({ :controller => alt_cont, :action => action            }) rescue nil
      return alt_url if alt_url
    end

    # Method 2: hardcoded equivalences
    alt_url = case [ controller, action ]

      when %w( nh_users    myaccount )
        user_path(:id => current_user.id)

      when %w( users       show ) # in CBRAIN some users can view other users...
        myaccount_path # but not in NeuroHub, we can only view our own account

      when %w( nh_projects files )
        switch_groups_path(:id => id)

      when %w( userfiles   index )
        cur_proj_id = current_project.try(:id)
        if cur_proj_id
          files_nh_project_path(:id => cur_pro_id)
        else
          nh_projects_path
        end

    end
    return alt_url if alt_url

    # No equivalent page
    nil
  end

  # This method acts like alternate_link_path
  # except if not alternate page exists, it
  # return a path to the dashboard of the alternative
  # interface.
  def alternate_page_or_dashboard_path
    alternate_link_path || alternate_dashboard_path
  end

end

