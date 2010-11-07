module RequestsPermission

  protected

  #
  # REST
  #

  def may_destroy_request?(req=@request)
return false
    logged_in? and req.may_destroy?(current_user)
  end

  def may_update_request?(req=@request)
    logged_in? and (req.may_approve?(current_user) or req.may_vote?(current_user))
  end

  def may_show_request?(req=@request)
    logged_in? and req.may_view?(current_user)
  end

  #%w(approve reject).each{ |action|
  #  alias_method "may_#{action}_request?".to_sym, :may_update_request?
  #}
  #
  #def may_mark_request?
  #  logged_in?
  #end
  #
  #def may_redeem_request?(req=@request)
  #  logged_in?
  #end
  #

end
