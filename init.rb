# frozen_string_literal: true

# Redmine Easy Parent Child Plugin
# Copyright (C) 2025
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine'

Redmine::Plugin.register :redmine_easy_parent_child do
  name 'Easy Parent Child'
  author 'Redmine Easy Parent Child Plugin Team'
  description 'Easy parent-child relationship setting with drag & drop'
  version '1.0.0'
  url 'https://github.com/redmine/redmine_easy_parent_child'
  author_url 'https://github.com/redmine'
  
  # Load locales
  if Rails.version >= '5.2'
    Rails.application.config.i18n.load_path += Dir.glob(File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml'))
  else
    I18n.load_path += Dir.glob(File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml'))
  end

  # プラグインの権限を定義
  permission :view_easy_parent_child, {
    :easy_parent_childs => [:show, :update_relations]
  }, :read => true

  # プロジェクトメニューに追加
  menu :project_menu, :easy_parent_child, 
       { :controller => 'easy_parent_childs', :action => 'show' },
       :caption => :label_easy_parent_child,
       :param => :project_id,
       :permission => :view_easy_parent_child,
       :if => Proc.new { |p| p.module_enabled?(:easy_parent_child) }

  # 独立したプロジェクトモジュールとして登録
  project_module :easy_parent_child do
    permission :view_easy_parent_child, {
      :easy_parent_childs => [:show, :update_relations]
    }, :read => true
  end
end

# プラグインのアセットを読み込む
Rails.application.config.assets.precompile += %w( easy_parent_child.js easy_parent_child.css )
