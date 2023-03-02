% The code gets a direcory of images are operate the "analyze_state" function 
% for every 8 images (4xprev + 4xcur)
clc
clear all
close all
set(0,'DefaultFigureWindowStyle','docked');
warning('off');

global folder_name

% ----------------------------------

% App satate
global app_state
app_state = "Idle";

% Define camera objects
global cam_top cam_left cam_right cam_back cam_demo

% Is demo cam
global isDemo
isDemo = true;
global isImgFromFile
isImgFromFile = true;

% Counter for capture and save
global capture_and_save_img_counter
capture_and_save_img_counter = 0;

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

global game_occupied_matrix
game_occupied_matrix = zeros([grid_size grid_size grid_size]);

% -------- Settings: ---------------

% Put images in ProjectFolder/DemoImages/folder_name

folder_name = "set_17_2_22";
series_first_number = 1;
series_last_number = -1; % set (-1) to run to the end
% ----------------------------------

loop_idx = series_first_number;

% Get path of all 8 files
prev_top_path = img_path("top",loop_idx);
prev_left_path = img_path("left",loop_idx);
prev_right_path = img_path("right",loop_idx);
prev_back_path = img_path("back",loop_idx);

cur_top_path = img_path("top",loop_idx+1);
cur_left_path = img_path("left",loop_idx+1);
cur_right_path = img_path("right",loop_idx+1);
cur_back_path = img_path("back",loop_idx+1);

images_exist = exist_img(prev_top_path) && exist_img(prev_left_path) &&...
               exist_img(prev_right_path) && exist_img(prev_back_path) &&...  
               exist_img(cur_top_path) && exist_img(cur_left_path) &&...
               exist_img(cur_right_path) && exist_img(cur_back_path);

while images_exist && (loop_idx)~=series_last_number

    close all

    % Read images
    prev_top = imread(prev_top_path);
    prev_left = imread(prev_left_path);
    prev_right = imread(prev_right_path);
    prev_back = imread(prev_back_path);

    cur_top = imread(cur_top_path);
    cur_left = imread(cur_left_path);
    cur_right = imread(cur_right_path);
    cur_back = imread(cur_back_path);

    % Call analyze_state function
    [cube_change_detected, cube_status_add_or_sub, lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height, lego_cube_color] = analyze_state(cur_top, prev_top, cur_left, prev_left, cur_right, prev_right, cur_back, prev_back);

    if cube_status_add_or_sub == 1
        cube_status = "ADD";
    elseif cube_status_add_or_sub == -1
        cube_status = "REMOVE";
    else
        cube_status = "MISMATCH";
    end


    % Display results
    if cube_change_detected
        disp([cube_status,lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height, lego_cube_color]);
    else
        disp("No cube detected in this state");
    end
    disp("------------------------------------------------------------------------");

    if lego_grid_x == 11 && lego_grid_y == 6 && lego_grid_z == 1
        disp("Breakpoint");
    end

    % Move to next images
    loop_idx = loop_idx + 1;

    % Get path of all 8 files
    prev_top_path = img_path("top",loop_idx);
    prev_left_path = img_path("left",loop_idx);
    prev_right_path = img_path("right",loop_idx);
    prev_back_path = img_path("back",loop_idx);
    
    cur_top_path = img_path("top",loop_idx+1);
    cur_left_path = img_path("left",loop_idx+1);
    cur_right_path = img_path("right",loop_idx+1);
    cur_back_path = img_path("back",loop_idx+1);
    
    images_exist = exist_img(prev_top_path) && exist_img(prev_left_path) &&...
                   exist_img(prev_right_path) && exist_img(prev_back_path) &&...  
                   exist_img(cur_top_path) && exist_img(cur_left_path) &&...
                   exist_img(cur_right_path) && exist_img(cur_back_path);

    close all


end

%% Functions

function res = exist_img(img_path)
    res = logical(exist(img_path,'file') == 2);
end

function img_path = img_path(cam_name,img_num)
    global folder_name
    file_name = "cam_"+cam_name+"_"+num2str(img_num)+".bmp";
    img_path = fullfile("DemoImages",folder_name,file_name);
end

