
class UserWithName
  # This class exists to help "sneak" the user listings through the PDF exporter
  # Really we should just override and fix the PDF exporter to know that strings
  # might be in the list.
  attr_reader :name, :project, :start_date
  def initialize(name,project,start_date)
    @name = name
    @project = project
    @start_date = start_date
  end
end

class GanttByUser < Redmine::Helpers::Gantt
  attr_reader :show_undated

  def initialize(options={},project=nil)
    if options[:show_undated] && options[:show_undated].to_i >= 0 && options[:show_undated].to_i <= 1 then
      @show_undated = options[:show_undated].to_i
      Rails.logger.info "In GanntByUser.initialize, set show_undated to #{show_undated.to_s}.\n"
    else
      @show_undated = 0
      Rails.logger.info "In GanntByUser.initialize, set show_undated to default 0.\n"
    end
    @project = project
    Rails.logger.info "In GanntByUser, setting project to #{project}.\n"
    # Save gantt parameters as user preference (zoom and months count)
    if (User.current.logged? && (@show_undated != User.current.pref[:show_undated])) then
      User.current.pref[:show_undated] = @show_undated
    end
    # Call super after to take advantage of pref.save there
    super(options)
  end
  
  def params
    ret = super
    ret[:show_undated] = @show_undated
    ret
  end
  
  def params_previous
    ret = super
    ret[:show_undated] = @show_undated
    ret
  end
  
  def params_next
    ret = super
    ret[:show_undated] = @show_undated
    ret
  end

  def events=(es)
    Rails.logger.info "In GanntByUser.show, show_undated is #{@show_undated}.\n"
    if @show_undated != 1 then
      Rails.logger.info "In GanntByUser.show, removing undated events.\n"
      # Removes issues that have no start or end date
      es.reject! {|i| i.is_a?(Issue) && (i.start_date.nil? || i.due_before.nil?) }
    end
    # Insert the user at each point where it changes
    events_out = []
    # We use this integer so that even the nil user will trigger a new listing
    last_assigned = -1
    es.each do |event|
      if event.is_a?(Issue) and event.assigned_to != last_assigned then
        last_assigned = event.assigned_to
        if last_assigned == nil then
          events_out << UserWithName.new(I18n.t(:unassigned_user),@project,@date_from)
        else
          events_out << UserWithName.new(last_assigned,@project,@date_from)
        end
      end
      events_out << event
    end
    @events = events_out
    @events
  end
end

class GanttByUserController < ApplicationController
  unloadable
  menu_item :gantt_by_user
  before_filter :find_optional_project

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :issues
  helper :projects
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  include Redmine::Export::PDF
  
  def show
    #@project = Project.find(params[:project_id])
    @gantt = GanttByUser.new(params,@project)
    logger.debug "In show, initialized GannttByUser.\n"
    retrieve_query
    @query.group_by = [ :start_date ]
    if @query.valid?
      events = []
      # Issues that have start and due dates
      events += @query.issues(:include => [:tracker, :assigned_to, :priority],
                              :order => "users.lastname, users.firstname, start_date, due_date" #,
                              #:conditions => ["(((start_date>=? and start_date<=?) or (due_date>=? and due_date<=?) or (start_date<? and due_date>?)) and start_date is not null and due_date is not null)", @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to]
                              )
      # Issues that don't have a due date but that are assigned to a version with a date
      events += @query.issues(:include => [:tracker, :assigned_to, :priority, :fixed_version],
                              :order => "start_date, effective_date",
                              :conditions => ["(((start_date>=? and start_date<=?) or (effective_date>=? and effective_date<=?) or (start_date<? and effective_date>?)) and start_date is not null and due_date is null and effective_date is not null)", @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to]
                              )
      # Versions
      events += @query.versions(:conditions => ["effective_date BETWEEN ? AND ?", @gantt.date_from, @gantt.date_to])
                                   
      @gantt.events = events
    end
    
    basename = (@project ? "#{@project.identifier}-" : '') + 'gantt'
    
    respond_to do |format|
      format.html { render :action => "show", :layout => !request.xhr? }
      format.png  { send_data(@gantt.to_image(@project), :disposition => 'inline', :type => 'image/png', :filename => "#{basename}.png") } if @gantt.respond_to?('to_image')
      format.pdf  { send_data(gantt_to_pdf(@gantt, @project), :type => 'application/pdf', :filename => "#{basename}.pdf") }
    end
  end

end
