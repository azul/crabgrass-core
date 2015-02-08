class Groups::StructuresController < Groups::SettingsController

  guard :may_edit_group_structure?, actions: [:new, :create, :destroy]

  def show
  end

  def new
    if group_type == :committee
      @committee = Committee.new
    elsif group_type == :council
      @council = Council.new
    end
  end

  #
  # not very DRY, but we need properly named @var for the create form to work.
  #
  def create
    if group_type == :committee
      raise_denied unless may_create_committee?
      @committee = @group.committees.add! committee_params
      redirect_to group_url(@committee)
    elsif group_type == :council
      raise_denied unless may_create_council?
      @council = @group.add_council! council_params
      redirect_to group_url(@council)
    end
    success
  end

  protected

  def group_type
    case params[:type]
      when 'committee' then :committee
      when 'council' then :council
      else raise 'error'
    end
  end
  helper_method :group_type

  def group_class
    case group_type
      when :council then Council
      when :committee then Committee
      else raise 'error'
    end
  end

  def committee_params
    params.require(:committee).
      permit(:name, :full_name, :language).
      merge created_by: current_user
  end

  def council_params
    params.require(:council).
      permit(:name, :full_name, :language).
      merge created_by: current_user
  end

end
