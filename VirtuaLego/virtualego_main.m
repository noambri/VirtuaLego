%% Clear and close
clc
clear all
all_fig = findall(0, 'type', 'figure');
close(all_fig)
set(0,'DefaultFigureWindowStyle','docked');
warning('off');
%% Define vars

% App sata4te
global app_state
app_state = "Idle";

global is_game_running
is_game_running = false;

% Define camera objects
global cam_top cam_left cam_right cam_back cam_demo

% Is demo cam
global isDemo
isDemo = false;
global isImgFromFile 
isImgFromFile = false;

% Counter for capture and save
global capture_and_save_img_counter
capture_and_save_img_counter = 0;
global capture_and_save_set_name
capture_and_save_set_name = "Empty";
global sequence_capture_and_save_seq_counter
sequence_capture_and_save_seq_counter = 0;


global cam_width cam_height
cam_width = 640;
cam_height = 480;

global grid_size
grid_size = 24;

global top_img_size top_img_grid_resolution
top_img_size = 480;
top_img_grid_resolution = top_img_size/grid_size;

global side_img_trapz_row side_img_trapz_width
side_img_trapz_row = 360;
side_img_trapz_width = 560;

global game_occupied_matrix game_occupied_matrix_prev_state
game_occupied_matrix = zeros([grid_size grid_size grid_size]);
game_occupied_matrix_prev_state = zeros([grid_size grid_size grid_size]);

global is_game_in_fix_cube_mode
is_game_in_fix_cube_mode = false;

global fix_cube_mode_axis_idx
fix_cube_mode_axis_idx = 1;
global fix_cube_mode_axis_options
fix_cube_mode_axis_options = ["LeftRight","ForwardBackward","UpDown"];

global has_cubes_on_board
global was_last_action_addition
global last_cube_x last_cube_y last_cube_z last_cube_w last_cube_h last_cube_color 

global is_game_in_undoing_last_move_mode
global skip_moving_cur_img_to_prev
global freeze_tracking_model_mode
global is_waiting_to_reset_start_app
is_waiting_to_reset_start_app = false;

global is_app_running
is_app_running = true;

%% Run app

% Start UI menu
open_menu_ui
%init_webcams();

function open_menu_ui
% UI menu

% Create figure window
fig = uifigure;
fig.Name = "VirtuaLego";

% Manage app layout
gl = uigridlayout(fig,[6 2]);

setup_cam_btn = uibutton(gl,'Text','Setup cameras','ButtonPushedFcn', @(btn,event) setup_cam_btn_pressed());
init_cam_btn = uibutton(gl,'Text','Init cameras','ButtonPushedFcn', @(btn,event) init_webcams());
capture_and_save_btn = uibutton(gl,'Text','Capture and save','ButtonPushedFcn', @(btn,event) cpature_and_save());
sequence_capture_and_save_btn = uibutton(gl,'Text','Sequence capture and save','ButtonPushedFcn', @(btn,event) camera_sequence_capture_and_save());
cam_live_watch_btn = uibutton(gl,'Text','Camera Live Watch','ButtonPushedFcn', @(btn,event) camera_livewatch());

calibrate_cameras_btn = uibutton(gl,'Text','Calibrate cameras','ButtonPushedFcn', @(btn,event) calibrate_cameras());
calibrate_masks_btn = uibutton(gl,'Text','Calibrate masks','ButtonPushedFcn', @(btn,event) calibrate_masks());
calibrate_colors_btn = uibutton(gl,'Text','Calibrate colors','ButtonPushedFcn', @(btn,event) set_ref_color_vec());
calibrate_ui_buttons_btn = uibutton(gl,'Text','Calibrate UI Buttons','ButtonPushedFcn', @(btn,event) calibrate_ui_buttons());
start_app_btn = uibutton(gl,'Text','Start App','ButtonPushedFcn', @(btn,event) start_app());
stop_app_btn = uibutton(gl,'Text','Stop Cur Game','ButtonPushedFcn', @(btn,event) stop_cur_game());
stop_app_btn = uibutton(gl,'Text','Stop App','ButtonPushedFcn', @(btn,event) stop_app());


end

function stop_app()

    global app_state
    app_state = "Stop app";
    disp(["App state: ",app_state]);

    global is_game_running
    is_game_running = false;

    global is_waiting_to_reset_start_app
    is_waiting_to_reset_start_app = true;

    global is_app_running
    is_app_running = false;

end

function stop_cur_game()

    global app_state
    app_state = "Stop app";
    disp(["App state: ",app_state]);

    global is_game_running
    is_game_running = false;

    global is_waiting_to_reset_start_app
    is_waiting_to_reset_start_app = true;

    global is_app_running
    is_app_running = true;
end


