class Task::Participation < ActiveRecord::Base
  self.table_name = 'task_participations'
  belongs_to :user
  belongs_to :task
end
