class RankedVotePageController < Pages::BaseController
  before_filter :fetch_poll
  before_filter :edit_blank_polls, only: :show

  def show
    @presentation = RankedVote::Presentation.new(@poll)
    if may_edit_page?
      @own_choice = RankedVote::UsersChoice.new(@poll, current_user)
    end
  end

  def edit
    @own_choice = RankedVote::UsersChoice.new(@poll, current_user)
  end

  def print
    @presentation = RankedVote::Presentation.new(@poll)
    render layout: "printer-friendly"
  end

  protected

  def fetch_poll
    @poll = @page.data if @page
    true
  end

  def setup_options
    # @options.show_print = true
    @options.show_tabs = true
  end

  def edit_blank_polls
    # we need to specify the whole page_url not just the action here
    # because we might have ended up here from the DispatchController.
    if @poll.possibles.blank? && logged_in?
      redirect_to page_url(@page, action: :edit)
    end
  end

end

