# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

class EasyParentChildsController < ApplicationController
  menu_item :easy_parent_child
  before_action :find_optional_project
  before_action :authorize, :except => [:show]

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :gantt
  helper :issues
  helper :projects
  helper :queries
  include QueriesHelper

  def show
    # 独立したフィルタークエリを作成
    @query = build_easy_parent_child_query
    @issues = find_filtered_issues
    
    # @issuesに含まれるチケットの全子孫を再帰的に取得して追加
    all_descendants = collect_all_descendants(@issues.map(&:id))
    if all_descendants.any?
      descendant_issues = Issue.where(id: all_descendants)
        .includes(:status, :tracker, :assigned_to, :priority, :category, :fixed_version, :parent)
      # 既存の@issuesとマージ（重複を避ける）
      existing_ids = @issues.map(&:id).to_set
      new_issues = descendant_issues.reject { |issue| existing_ids.include?(issue.id) }
      @issues = (@issues.to_a + new_issues.to_a).uniq
    end
    
    # 各チケットの子チケット情報を事前に取得
    @issues_with_children = {}
    @issues.each do |issue|
      begin
        @issues_with_children[issue.id] = issue.children.to_a
      rescue => e
        Rails.logger.warn "Failed to get children for issue #{issue.id}: #{e.message}"
        @issues_with_children[issue.id] = []
      end
    end
    
    respond_to do |format|
      format.html { render :action => "show", :layout => !request.xhr? }
    end
  end

  def update_relations
    authorize
    
    begin
      relations_data = params[:relations] || {}
      updated_count = 0
      
      relations_data.each do |parent_id, children_ids|
        parent_issue = Issue.find(parent_id)
        
        # 既存の子チケットのparent_idをクリア（ただし、新しい子チケットリストに含まれるものは除外）
        existing_children = Issue.where(parent_id: parent_id)
        existing_children.each do |existing_child|
          unless children_ids.map(&:to_s).include?(existing_child.id.to_s)
            existing_child.parent_id = nil
            existing_child.save
          end
        end
        
        # 新しい子チケット関係を作成
        children_ids.each do |child_id|
          next if child_id.blank?
          
          child_issue = Issue.find(child_id)
          
          # 循環参照をチェック
          # 1. 自分自身を子にしようとする場合
          # 2. 子の子孫に親が含まれている場合（親が子の子孫になろうとする場合）
          # 3. 親が既に親を持っている場合、親の親（または親の祖先）が子になろうとする場合
          if child_issue.id == parent_issue.id || 
             child_issue.descendants.include?(parent_issue)
            next
          end
          
          # 親が既に親を持っている場合、親の祖先が子になろうとする場合をチェック
          has_circular_reference = false
          if parent_issue.parent_id.present?
            # 親の親が直接子になろうとする場合
            if child_issue.id == parent_issue.parent_id
              has_circular_reference = true
            else
              # 親の親の子孫が子になろうとする場合をチェック（再帰的にチェック）
              current_parent = parent_issue.parent
              while current_parent.present? && !has_circular_reference
                if child_issue.id == current_parent.id || 
                   child_issue.descendants.include?(current_parent)
                  has_circular_reference = true
                  break
                end
                current_parent = current_parent.parent
              end
            end
          end
          
          # 循環参照が見つかった場合はスキップ
          if has_circular_reference
            next
          end
          
          child_issue.parent_id = parent_id
          if child_issue.save
            updated_count += 1
          end
        end
      end
      
      render json: { 
        success: true, 
        message: l(:text_relations_updated, count: updated_count),
        updated_count: updated_count
      }
      
    rescue ActiveRecord::RecordNotFound => e
      render json: { 
        success: false, 
        message: l(:error_issue_not_found, message: e.message) 
      }, status: 404
    rescue => e
      render json: { 
        success: false, 
        message: l(:error_general, message: e.message) 
      }, status: 500
    end
  end

  def disconnect_relation
    authorize
    
    begin
      issue_id = params[:issue_id]
      
      if issue_id.blank?
        render json: { 
          success: false, 
          message: l(:error_issue_not_found, message: 'Issue ID is required') 
        }, status: 400
        return
      end
      
      issue = Issue.find(issue_id)
      
      unless issue.parent_id.present?
        render json: { 
          success: false, 
          message: l(:error_no_parent_relation) 
        }, status: 400
        return
      end
      
      # 親子関係を切断
      # このチケットとその子孫（すべての子孫チケット）が独立したツリーとして分離されます
      # 例: A-B-C-D-E の場合、Cで切断すると A-B と C-D-E に分かれます
      parent_id = issue.parent_id
      issue.parent_id = nil
      
      if issue.save
        # 子孫の数を取得してメッセージに含める
        # 保存後に再取得して最新の状態を取得
        issue.reload
        descendant_ids = collect_all_descendants([issue.id])
        descendant_count = descendant_ids.count
        message = if descendant_count > 0
          l(:text_relation_disconnected_with_descendants, issue_id: issue_id, parent_id: parent_id, count: descendant_count)
        else
          l(:text_relation_disconnected, issue_id: issue_id, parent_id: parent_id)
        end
        
        render json: { 
          success: true, 
          message: message
        }
      else
        render json: { 
          success: false, 
          message: l(:error_failed_to_disconnect, errors: issue.errors.full_messages.join(', ')) 
        }, status: 422
      end
      
    rescue ActiveRecord::RecordNotFound => e
      render json: { 
        success: false, 
        message: l(:error_issue_not_found, message: e.message) 
      }, status: 404
    rescue => e
      render json: { 
        success: false, 
        message: l(:error_general, message: e.message) 
      }, status: 500
    end
  end

  private

  # @issuesに含まれるチケットの全子孫を再帰的に取得
  def collect_all_descendants(issue_ids)
    return [] if issue_ids.empty?
    
    # 直接の子を取得
    children_ids = Issue.where(parent_id: issue_ids).pluck(:id)
    return [] if children_ids.empty?
    
    # 子孫を再帰的に取得
    descendant_ids = children_ids + collect_all_descendants(children_ids)
    descendant_ids.uniq
  end

  def build_easy_parent_child_query
    query = IssueQuery.new
    query.project = @project
    query.name = l(:label_easy_parent_child_filter)
    query.visibility = Query::VISIBILITY_PRIVATE
    query.user = User.current
    
    # フィルター条件を設定
    if params[:f].present?
      params[:f].each do |field, values|
        next if values.blank?
        query.add_filter(field, '=', values)
      end
    end
    
    # デフォルトフィルター（制限）
    query.add_filter('limit', '=', ['100']) unless params[:f]&.key?('limit')
    
    query
  end

  def find_filtered_issues
    issues = @project ? @project.issues : Issue.all
    
    # 基本フィルター
    issues = apply_basic_filters(issues)
    
    # 高度なフィルター
    issues = apply_advanced_filters(issues)
    
    # 制限を適用
    limit = params[:limit].present? ? params[:limit].to_i : 100
    issues = issues.limit(limit)
    
    # 親子関係の情報を含めて取得
    issues.includes(:status, :tracker, :assigned_to, :priority, :category, :fixed_version, :parent)
  end

  def apply_basic_filters(issues)
    # ステータスフィルター
    if params[:status_id].present?
      issues = issues.where(status_id: params[:status_id])
    end
    
    # トラッカーフィルター
    if params[:tracker_id].present?
      issues = issues.where(tracker_id: params[:tracker_id])
    end
    
    # 担当者フィルター
    if params[:assigned_to_id].present?
      issues = issues.where(assigned_to_id: params[:assigned_to_id])
    end
    
    # 優先度フィルター
    if params[:priority_id].present?
      issues = issues.where(priority_id: params[:priority_id])
    end
    
    # カテゴリフィルター
    if params[:category_id].present?
      issues = issues.where(category_id: params[:category_id])
    end
    
    # バージョンフィルター
    if params[:fixed_version_id].present?
      issues = issues.where(fixed_version_id: params[:fixed_version_id])
    end
    
    issues
  end

  def apply_advanced_filters(issues)
    # 日付フィルター
    if params[:start_date].present?
      issues = issues.where('start_date >= ?', Date.parse(params[:start_date]))
    end
    
    if params[:due_date].present?
      issues = issues.where('due_date <= ?', Date.parse(params[:due_date]))
    end
    
    # テキスト検索
    if params[:subject].present?
      issues = issues.where('subject LIKE ?', "%#{params[:subject]}%")
    end
    
    # 親チケットフィルター
    case params[:parent_filter]
    when 'with_parent'
      issues = issues.where.not(parent_id: nil)
    when 'without_parent'
      issues = issues.where(parent_id: nil)
    end
    
    # 作成者フィルター
    if params[:author_id].present?
      issues = issues.where(author_id: params[:author_id])
    end
    
    issues
  end

  def find_optional_project
    @project = Project.find(params[:project_id]) if params[:project_id]
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
