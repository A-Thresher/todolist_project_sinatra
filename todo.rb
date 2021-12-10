require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_done(list)
    completed = list[:todos].select { |todo| !todo[:completed] }.count
    "#{completed} / #{list[:todos].size}"
  end

  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each { |list| yield(list, lists.index(list)) }
    complete.each { |list| yield(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    incomplete = {}
    complete = {}

    todos.each_with_index do |todo, index|
      todo[:completed] ? complete[todo] = index : incomplete[todo] = index
    end

    incomplete.each(&block)
    complete.each(&block)
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single list
get "/lists/:index" do
  @list = session[:lists][params[:index].to_i]
  erb :list, layout: :layout
end

# Render edit list form
get "/lists/:index/edit" do
  @list = session[:lists][params[:index].to_i]
  erb :edit_list, layout: :layout
end

# Edit list
post "/lists/:index" do
  list_name = params[:list_name].strip
  @list = session[:lists][params[:index].to_i]

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been renamed."
    redirect "/lists/#{params[:index]}"
  end
end

# Delete list
post "/lists/:index/delete" do
  session[:lists].delete_at(params[:index].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add todo
post "/lists/:index/todos" do
  todo_name = params[:todo].strip
  @list = session[:lists][params[:index].to_i]

  error = error_for_todo(todo_name)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{params[:index]}"
  end
end

# Delete todo
post "/lists/:index/todos/:todo_index/delete" do
  list = session[:lists][params[:index].to_i]
  list[:todos].delete_at(params[:todo_index].to_i)
  session[:success] = "The todo has been deleted"
  redirect "/lists/#{params[:index]}"
end

# Change todo completion status
post "/lists/:index/todos/:todo_index" do
  todo = session[:lists][params[:index].to_i][:todos][params[:todo_index].to_i]
  is_completed = params[:completed] == "true"
  todo[:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{params[:index]}"
end

# Change all todos to complete
post "/lists/:index/complete_all" do
  todos = session[:lists][params[:index].to_i][:todos]
  todos.each { |todo| todo[:completed] = true }
  session[:success] = "All todo items marked complete."
  redirect "/lists/#{params[:index]}"
end
