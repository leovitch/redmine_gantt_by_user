require 'redmine'

Redmine::Plugin.register :redmine_gantt_by_user do
  name 'Redmine Gantt By User plugin'
  author 'Leo Hourvitz'
  description 'Generate Gantt chart sorted by User'
  version '0.0.1'
  url 'http://github.com/leovitch'
  author_url 'http://www.stoneschool.com/'
  permission :gantt_by_user, {:gantt_by_user => [:show]}, :public => true
  menu :project_menu, :gantt_by_user, { :controller => 'gantt_by_user', :action => 'show' }, :after => :gantt, :param => :project_id, :caption => :title_gantt_by_user
end

