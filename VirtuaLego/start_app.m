function start_app()
    global app_state
    global isDemo
    global game_occupied_matrix game_occupied_matrix_prev_state
    global grid_size
    global has_cubes_on_board
    global last_cube_x last_cube_y last_cube_z last_cube_w last_cube_h last_cube_color
    global is_app_running
    global is_game_running
    global is_game_in_fix_cube_mode
    global fix_cube_mode_axis_idx
    global fix_cube_mode_axis_options
    global is_game_in_undoing_last_move_mode
    global skip_moving_cur_img_to_prev
    global freeze_tracking_model_mode
    global is_waiting_to_reset_start_app

    while is_app_running

        app_state = "Start app";
        disp(["App state: ",app_state]);
    
        game_occupied_matrix = zeros([grid_size grid_size grid_size]);
        game_occupied_matrix_prev_state = zeros([grid_size grid_size grid_size]);
        has_cubes_on_board = false;
         
        last_cube_x = -1;
        last_cube_y = -1;
        last_cube_z = -1;
        last_cube_w = -1;
        last_cube_h = -1;
        last_cube_color = "Empty";
    
        is_game_running  = true;
        is_game_in_fix_cube_mode = false;
        is_game_in_undoing_last_move_mode = false;
        skip_moving_cur_img_to_prev = false;
        freeze_tracking_model_mode = false;
        is_waiting_to_reset_start_app = false;
        
        % Init the model
        reset_model_txt_descriptor();
        game_occupied_matrix = initiate_game_occupied_matrix();
        
        disp("Get first stable frames:")
    
        % Get the first image from the top cam:
        cur_stable_top_image = get_stable_frame_from_top_cam();
        % Get left,right,back images of the stable state
        [cur_stable_left_image,cur_stable_right_image,cur_stable_back_image] = get_left_right_back_images();
        
        % Button var
        amount_of_buttons = 5;
        % Load buttons transformations
        button_img_tforms = load_button_image_transformations();
    
        disp("Enter app loop");
    
        % The top cam is contineusly capturing and looking for a "stable state"
        while is_game_running
            wait_for_movement_in_scene(amount_of_buttons, button_img_tforms); % Wait for some state changing
            
            new_data = "[Status,DetectMove]";
            add_data_to_model_txt_descriptor(new_data);
        
            if is_waiting_to_reset_start_app
                break;
            end
    
            % ---- If we are here, some change in the scene -----
            pause(1);
            if ~skip_moving_cur_img_to_prev
                prev_stable_top_image = cur_stable_top_image; % Store the last stable frame
            end
            cur_stable_top_image = get_stable_frame_from_top_cam(); % Wait for stability
            % Wait one sec before taking the real stable image
            pause(0.5);
            
            new_data = "[Status,AnalyzeState]";
            add_data_to_model_txt_descriptor(new_data);
                
            if is_game_running
    
                cur_stable_top_image = get_stable_frame_from_top_cam();
        
                % Get left,right,back images of the stable state
                if ~skip_moving_cur_img_to_prev
                    prev_stable_left_image = cur_stable_left_image;
                    prev_stable_right_image = cur_stable_right_image;
                    prev_stable_back_image = cur_stable_back_image;
                else
                    % After finishing the undoing. remove the flag to normal
                    skip_moving_cur_img_to_prev = false;
                end
                [cur_stable_left_image,cur_stable_right_image,cur_stable_back_image] = get_left_right_back_images();
                
                close all
                [cube_change_detected, cube_status_add_or_sub, lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height, lego_cube_color] = analyze_state(cur_stable_top_image,...
                                                                                                                           prev_stable_top_image,...
                                                                                                                           cur_stable_left_image,...
                                                                                                                           prev_stable_left_image,...
                                                                                                                           cur_stable_right_image,...
                                                                                                                           prev_stable_right_image,...
                                                                                                                           cur_stable_back_image,...
                                                                                                                           prev_stable_back_image);
                if cube_change_detected
        
                    if cube_status_add_or_sub == 1 % Addition
                        % Add the cube to the model descriptor
                        add_block_to_model_txt_descriptor(lego_grid_x,...
                                                          lego_grid_y,...
                                                          lego_grid_z,...
                                                          lego_grid_width,...
                                                          lego_grid_height,...
                                                          lego_cube_color);
                        
                        % Debug printing
                        disp(["Add cube",lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height, lego_cube_color]);
                        disp("------------------------------------------------------------------------");
                    elseif cube_status_add_or_sub == -1 % Removal
                        % Remove cube from the model descriptor
                        remove_block_from_model_txt_descriptor(lego_grid_x,...
                                                          lego_grid_y,...
                                                          lego_grid_z,...
                                                          lego_grid_width,...
                                                          lego_grid_height,...
                                                          lego_cube_color);
                        
                        % Debug printing
                        disp(["Remove cube",lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height]);
                        disp("------------------------------------------------------------------------");
                    else
                        % Debug printing
                        disp(["MISMATHCED!",lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height, lego_cube_color]);
                        disp("------------------------------------------------------------------------");
                        skip_moving_cur_img_to_prev = true;
                        disp("Stay with old ref images");
                    end
                else
                    disp("No new cube detected in analyze state");
                    skip_moving_cur_img_to_prev = true;
                     disp("Stay with old ref images");
                end
        
                %cont = input("To cont?");
                %close all
                pause(0.1);
            end
        end
    
        disp("<< SESSION STOPPED >>");
    
    end
end

function stable_img = get_stable_frame_from_top_cam()

    % The function returns a stable image from the top cam
    

    global app_state
    app_state = "Scan for stable frame from top cam";
    disp(["App state: ",app_state]);

    global cam_top cam_left cam_right cam_back cam_demo
    selected_cam = cam_top;

    global is_game_running
    
    start(selected_cam);
    trigger(selected_cam);

    
    % Set the memory length
    mem_len = 3;
    % Set the images places in the memory we want to comper the last image to
    ref_img_num_in_mem = [1,2,mem_len];
    ref_img_arr_len = length(ref_img_num_in_mem);
    % Set stable check array
    is_stable_array = zeros(size(ref_img_num_in_mem));
       
    % Get first image
    init_img = capture_img(selected_cam);
    [img_row, img_col, img_dim] = size(init_img);
    % Initiate the memory for the first time
    mem_array = uint8(zeros(img_row, img_col, img_dim, mem_len));
    
    % Fill the memory
    for i=1:mem_len
        mem_array(:,:,:,i) = capture_img(selected_cam);
    end    
      
    %stable_counter = 0;
    % Get images and check stability
     while is_game_running
        % Take a new image to compare to the image in the memory
        cur_img = capture_img(selected_cam);
        
        % Check stability with the memory array
        for i=1:ref_img_arr_len
            ref_img = mem_array(:,:,:,ref_img_num_in_mem(i)); % Take onr img from the memory
            is_stable_array(i) = check_if_frame_stable(cur_img,ref_img); % Check stability
            % If the images are not stable break the for loop to take new image
            if is_stable_array(i) == 0
                break;
            end
        end

        %stable_counter = stable_counter + 1;
        %disp("still not stable : "+num2str(stable_counter));
        
        % Check if the system is stable for all the memory length
        if sum(is_stable_array) == ref_img_arr_len
            break; % If stable brake the while loop
        end

        
        
        % Foword the memory array
        mem_array(:,:,:,1:end-1) = mem_array(:,:,:,2:end);
        mem_array(:,:,:,end) = cur_img;

        pause(0.05);

     end
     
     % If we are here, cur_img is a stable image

     % Stop top cam video
     stop(selected_cam);

     if is_game_running
        stable_img = cur_img;
     else
         stable_img = init_img;
     end

end

function wait_for_movement_in_scene(amount_of_buttons, button_img_tforms)
    % The function recognize unstable frame after a steady state
    % (for example, if the user enter his/her hand to the board area)
    % The function stop running when it detects unstable state 

    global app_state
    app_state = "Scan for unstable frame";
    disp(["App state: ",app_state]);

    global cam_top
    selected_cam = cam_top;

    global is_game_running

    global is_game_in_undoing_last_move_mode
    global freeze_tracking_model_mode
    global is_waiting_to_reset_start_app
    
    % Buttons vars
    

    buttons_pushed_counter = zeros(1,amount_of_buttons);
    buttons_released_counter = zeros(1,amount_of_buttons);
    buttons_frames_to_pressed = 10;
    button_frame_to_release = 2;
    is_button_press_array = zeros(1,amount_of_buttons);

    cur_frames_to_activate_buttons = 0;
    target_frames_to_activate_buttons = 2;
    are_buttons_active = false;
    stable_fram_counter = 0;
    
    start(selected_cam);
    trigger(selected_cam);

    % Get first image
    ref_img = capture_img(selected_cam);

    %unstable_counter = 0;
    % Get images and check stability
    %btn_fig = figure;
    
    new_data = "[Status,WaitForMovement]";
    add_data_to_model_txt_descriptor(new_data);
    
    while is_game_running && ~is_waiting_to_reset_start_app
        % Take a new image to compare to the image in the init image
        cur_img = capture_img(selected_cam);

        %disp("Wait for unstable: "+num2str(unstable_counter));
        %unstable_counter = unstable_counter + 1;
        % Check stability
        is_stable = check_if_frame_unstable(cur_img,ref_img);

        if is_stable == false && ~is_game_in_undoing_last_move_mode && ~freeze_tracking_model_mode % If frame is not stable and we are not in removing cubes
            if stable_fram_counter == 2 % the system is stable
                %close(btn_fig);
                break;
            else
                stable_fram_counter = stable_fram_counter + 1; % count unstable frame
            end
        
        % In case the frame is stable - check buttons
        else
            stable_fram_counter = 0; % initiate the unstable fram counter to zero
            if are_buttons_active
                % Generate updated images of all buttons
                cur_button_img_array = get_buttons_img_arr_from_top_image(cur_img,button_img_tforms);
    
                % Check all buttons
                
                for i = 1:amount_of_buttons
                    if is_button_press_array(i) == 0 % If the button is not pressed
                        if buttons_pushed_counter(i) >= buttons_frames_to_pressed
                            buttons_pushed_counter(i) = 0; % clear counter
                            is_button_press_array(i) = 1; % button is press
                            %disp("Button "+ num2str(i) + " is press");
                            set_button_change_state(i,true);
                        else
                            loop_org_img(:,:,:) = buttons_org_img_array(:,:,:,i);
                            loop_cur_img(:,:,:) = cur_button_img_array(:,:,:,i);
                            [is_button_pushed_at_frame,~] = check_if_button_is_pushed_at_frame(loop_org_img,loop_cur_img);
                            if is_button_pushed_at_frame == true
                                buttons_pushed_counter(i) = buttons_pushed_counter(i) + 1;
                            else
                                buttons_pushed_counter(i) = 0; % clear counter if the user release the hand from the button
                            end
                        end
                    end
                end
                
                % Check is a press button was release
                for i = 1:amount_of_buttons
                    if is_button_press_array(i) == 1 % If the button is pressed
                        % If the button is press for "button_frame_to_release" times
                        if buttons_released_counter(i) >= button_frame_to_release
                            is_button_press_array(i) = 0; % release button
                            buttons_released_counter(i) = 0; % clear counter
                            %disp("Button "+ num2str(i) + " is release");
                            set_button_change_state(i,false);
                            
                        % If the button is press for lest than "button_frame_to_release" times    
                        elseif (buttons_released_counter(i) < button_frame_to_release)
                            % Check if the button is press or not
                            loop_org_img(:,:,:) = buttons_org_img_array(:,:,:,i);
                            loop_cur_img(:,:,:) = cur_button_img_array(:,:,:,i);
                            [is_button_pushed_at_frame,~] = check_if_button_is_released_at_frame(loop_org_img,loop_cur_img);
                            if is_button_pushed_at_frame == true
                                buttons_released_counter(i) = 0; % clear counter if the user release the hand from the button
                            else
                                buttons_released_counter(i) = buttons_released_counter(i) + 1; 
                            end
                        end
                    end
                end
    
                % ------- Disp buttons ----------
                %{
                for btn_idx = 1:amount_of_buttons
                    subplot(5,3,(btn_idx-1)*3 + 1);
                    loop_org_img(:,:,:) = buttons_org_img_array(:,:,:,btn_idx);
                    imshow(loop_org_img);
                    subplot(5,3,(btn_idx-1)*3 + 2);
                    loop_cur_img = cur_button_img_array(:,:,:,btn_idx);
                    imshow(loop_cur_img);
                    [~,btn_binary_map] = check_if_button_is_pushed_at_frame(buttons_org_img_array(:,:,:,btn_idx), cur_button_img_array(:,:,:,btn_idx));
                    subplot(5,3,(btn_idx-1)*3 + 3);
                    imshow(btn_binary_map);
                end
                %}
                % --------------------------------
            else
                cur_frames_to_activate_buttons = cur_frames_to_activate_buttons + 1;
                if cur_frames_to_activate_buttons >= target_frames_to_activate_buttons
                    are_buttons_active = true;

                    % Generate reference images for the buttons
                    buttons_org_img_array = get_buttons_img_arr_from_top_image(cur_img,button_img_tforms);
                end
            end
        end

        % Foword the current image to the ref image
        ref_img = cur_img;

        pause(0.1);

    end

    % If we are here, cur_img is an unstable image
    % Stop top cam video
    stop(selected_cam);
 
end

function is_frame_stable = check_if_frame_unstable(img1,img2)
    % check if img1 and img2 are similar enough to define as "stable state"
    
    % Set a threshold
    lower_threshold = 2000;
    upper_threshold = 100000;
    
    % Binary map and sum all the ones 
    % Normalized the images
    img1 = normalize_image(img1);
    img2 = normalize_image(img2);
    
    % Set binary map of the difference
    binary_map = images_diff_binary_map(img1, img2);

    
    sum_binary_map = sum(binary_map(:));
    if sum_binary_map > lower_threshold && sum_binary_map < upper_threshold
        is_frame_stable = false;
    else
        is_frame_stable = true;
    end
    %disp(sum(binary_map(:)));
end

function is_frame_stable = check_if_frame_stable(img1,img2)
    % check if img1 and img2 are similar enough to define as "stable state"
    
    % Set a threshold
    threshold = 200;
    
    % Binary map and sum all the ones 
    % Normalized the images
    img1 = normalize_image(img1);
    img2 = normalize_image(img2);
    
    % Set binary map of the difference
    binary_map = images_diff_binary_map(img1, img2);
    
    if sum(binary_map(:)) > threshold
        is_frame_stable = false;
    else
        is_frame_stable = true;
    end

    %disp(sum(binary_map(:)));
end

function [left_img,right_img,back_img] = get_left_right_back_images()
    global cam_left cam_right cam_back cam_demo

    global app_state
    app_state = "Capture left right back cam images";
    disp(["App state: ",app_state]);

    % Iterate over the 3 cameras and store the images
    camera_objects = [cam_left,cam_right,cam_back];
    for i=1:length(camera_objects)
        loop_cam_obg = camera_objects(i);
        start(loop_cam_obg);
        trigger(loop_cam_obg);
        loop_img = capture_img(loop_cam_obg);
        stop(loop_cam_obg);
    
        % Store the images
        switch i
            case 1
                left_img = loop_img;
            case 2
                right_img = loop_img;
            case 3
                back_img = loop_img;
        end
    end
end

%% Help functions

function ret_img = normalize_image(img)
    ret_img = double(img)/255;
end

function binary_map = images_diff_binary_map(prev_img, cur_img)
    % Create a binary map for stability test
    
    sub_images = cur_img - prev_img;

    sum_abs_cnl = abs(sub_images(:,:,1)) + abs(sub_images(:,:,2)) + abs(sub_images(:,:,3));
    sum_abs_cnl = sum_abs_cnl/max(sum_abs_cnl(:));

    bin_diff = imbinarize(sum_abs_cnl,0.2);
    bin_diff_cleaned = bwareaopen(bin_diff,200);
    
    binary_map = bin_diff_cleaned;
end

function binary_map = buttons_diff_binary_map(prev_img, cur_img)
    % Create a binary map for stability test
    
    sub_images = cur_img - prev_img;

    sum_abs_cnl = abs(sub_images(:,:,1)) + abs(sub_images(:,:,2)) + abs(sub_images(:,:,3));
    sum_abs_cnl = sum_abs_cnl/max(sum_abs_cnl(:));

    binary_map = imbinarize(sum_abs_cnl,0.45);
    binary_map = bwareaopen(binary_map,150);
    
end

%% Text functions

function reset_model_txt_descriptor()
    % Save "[empty_model]" node in the txt file
    fileID=fopen('model_descriptor.txt','w');
    fprintf(fileID,"[empty_model]");
    fclose(fileID);
end

function add_block_to_model_txt_descriptor(x_cube,y_cube,z_cube,w_cube,h_cube,color_cube)

    global app_state
    app_state = "Add cube to model descriptor";
    disp(["App state: ",app_state]);

    % Read the exist data in the txt file
    fileID = fopen('model_descriptor.txt','r');
    exist_data = fscanf(fileID,'%s');
    fclose(fileID);
    
    % Create the new block
    new_data = "[ADD,"+num2str(x_cube)+","+num2str(y_cube)+","+num2str(z_cube)+","+num2str(w_cube)+","+num2str(h_cube)+","+color_cube+"]";
    combined_data = exist_data+"&"+new_data;
    
    % Save the exist data and the new data in the txt file
    fileID=fopen('model_descriptor.txt','w');
    fprintf(fileID,combined_data);
    fclose(fileID);
end

function remove_block_from_model_txt_descriptor(x_cube,y_cube,z_cube,w_cube,h_cube,color_cube)

    global app_state
    app_state = "Add cube to model descriptor";
    disp(["App state: ",app_state]);

    % Read the exist data in the txt file
    fileID = fopen('model_descriptor.txt','r');
    exist_data = fscanf(fileID,'%s');
    fclose(fileID);
    
    % Create the new block
    new_data = "[REMOVE,"+num2str(x_cube)+","+num2str(y_cube)+","+num2str(z_cube)+","+num2str(w_cube)+","+num2str(h_cube)+","+color_cube+"]";
    combined_data = exist_data+"&"+new_data;
    
    % Save the exist data and the new data in the txt file
    fileID=fopen('model_descriptor.txt','w');
    fprintf(fileID,combined_data);
    fclose(fileID);
end

function add_data_to_model_txt_descriptor(new_data)

    global app_state
    app_state = "Add note to model descriptor";
    %disp(["App state: ",app_state]);

    % Read the exist data in the txt file
    fileID = fopen('model_descriptor.txt','r');
    exist_data = fscanf(fileID,'%s');
    fclose(fileID);
    
    % Create the new block
    combined_data = exist_data+"&"+new_data;
    
    % Save the exist data and the new data in the txt file
    fileID=fopen('model_descriptor.txt','w');
    fprintf(fileID,combined_data);
    fclose(fileID);
end

%% 3D cube

function zero_cube3D = initiate_game_occupied_matrix()
    % The function initiate a cube size 24*24*24 with zeros.
    % The cube represent the game area.

    global grid_size
    
    zero_cube3D = zeros([grid_size grid_size grid_size]);
    
end

function insert_cube_to_game_occupied_matrix(x,y,z,width_x,height_y)
    % The function enter a cube to the board game
    
    global game_occupied_matrix% board game
    
    % Set the bouad value (the 3D cube) to be ones in the wanted coordinate (x,y,z)
    game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1) = ones([height_y width_x 1]);
    
end

%% Buttons

function [is_button_pushed_at_frame,binary_map] = check_if_button_is_pushed_at_frame(original_button_img, cur_button_img)
    % The function checks if a button is pushed in one frame
    
    total_area = 40*40;

    threshold_per = 0.7;
    
    % Normalized the images
    original_button_img = normalize_image(original_button_img);
    cur_button_img = normalize_image(cur_button_img);
    
    % Set binary map of the difference
    binary_map = buttons_diff_binary_map(original_button_img, cur_button_img);
    
    if sum(binary_map(:)) > total_area * threshold_per
        is_button_pushed_at_frame = true;
    else
        is_button_pushed_at_frame = false;
    end
    
end

function [is_button_pushed_at_frame,binary_map] = check_if_button_is_released_at_frame(original_button_img, cur_button_img)
    % The function checks if a button is pushed in one frame
    
    total_area = 40*40;

    threshold_per = 0.7;
    
    % Normalized the images
    original_button_img = normalize_image(original_button_img);
    cur_button_img = normalize_image(cur_button_img);
    
    % Set binary map of the difference
    binary_map = buttons_diff_binary_map(original_button_img, cur_button_img);
    
    if sum(binary_map(:)) > total_area * threshold_per
        is_button_pushed_at_frame = true;
    else
        is_button_pushed_at_frame = false;
    end
    
end


function button_img_tforms = load_button_image_transformations()
    % Load button transforms
    load("buttons_tfrom.mat","button_img_tforms");
end

function btns_img_arr = get_buttons_img_arr_from_top_image(top_image,button_img_tforms)

    % The function gets top image and buttons transformations and return
    % (40,40,3,amount_of_buttons) matrix with the RGB images of all buttons

    global cam_width cam_height
    center_x = cam_width/2;
    center_y = cam_height/2;

    amount_of_buttons = 5;
    button_size = 40;
    btns_img_arr = zeros(button_size,button_size,3,amount_of_buttons); %(40,40,5)
    outputView = imref2d(size(top_image));

    for btn_idx = 1:amount_of_buttons
        loop_btn_trans = button_img_tforms{btn_idx};
        
        [btn_img_not_cropped,~] = imwarp(top_image,loop_btn_trans,'OutputView',outputView);

        % Cropping the image
        btn_img_cropped = btn_img_not_cropped(center_y - button_size/2 + 1 : center_y + button_size/2, ...
                                              center_x - button_size/2 + 1: center_x + button_size/2, :);

        btns_img_arr(:,:,:,btn_idx) = btn_img_cropped(:,:,:);

        btns_img_arr = uint8(btns_img_arr);
    end
end

%% Get image from cam

function img = capture_img(selected_cam)
    % img = ycbcr2rgb(getsnapshot(selected_cam));
    img = YUY2toRGB(getsnapshot(selected_cam));
end

%% Fixing cube

function enter_fix_cube_mode()
    global game_occupied_matrix game_occupied_matrix_prev_state
    global is_game_in_fix_cube_mode
    global fix_cube_mode_axis_idx

    is_game_in_fix_cube_mode = true;
    fix_cube_mode_axis_idx = 1;
end

function fix_last_cube_to_direction(left,up,forward)
    disp("fix_last_cube_to_direction: Left = "+num2str(left)+" , Up = "+num2str(up)+" , Forward = "+num2str(forward));
    global last_cube_x last_cube_y last_cube_z last_cube_w last_cube_h last_cube_color 
    last_cube_x = last_cube_x - left;
    last_cube_y = last_cube_y - forward;
    last_cube_z = last_cube_z + up;

    new_data = "[Status,"+"Fix cube in selected direction"+"]";
    add_data_to_model_txt_descriptor(new_data);
end

function undo_last_changed_cube()
    global game_occupied_matrix game_occupied_matrix_prev_state
    global is_game_in_fix_cube_mode
    global fix_cube_mode_axis_idx

    % Back to the game_occupied_matrix before change
    game_occupied_matrix = game_occupied_matrix_prev_state;

    % Exit from is_game_in_fix_cube_mode mode
    is_game_in_fix_cube_mode = false;

    % Enter to undoing last change mode
    global is_game_in_undoing_last_move_mode
    is_game_in_undoing_last_move_mode = true;

end

function apply_undoing_last_changed_cube()
    global is_game_in_undoing_last_move_mode skip_moving_cur_img_to_prev
    is_game_in_undoing_last_move_mode = false;

    % Mark that we need to keep the 
    skip_moving_cur_img_to_prev = true;
end

function exit_fix_cube_mode()
    global game_occupied_matrix game_occupied_matrix_prev_state
    global is_game_in_fix_cube_mode
    global last_cube_x last_cube_y last_cube_z last_cube_w last_cube_h last_cube_color 
    global has_cubes_on_board
    global was_last_action_addition
    
    if has_cubes_on_board
        % Back to the game_occupied_matrix before change
        game_occupied_matrix = game_occupied_matrix_prev_state;

        % Apply the fixed cube to the board in it's prev state
        if was_last_action_addition
            insert_cube_to_game_occupied_matrix_duplicated(last_cube_x,last_cube_y,last_cube_z,last_cube_w,last_cube_h,last_cube_color);
        else
            remove_cube_from_game_occupied_matrix_duplicated(last_cube_x,last_cube_y,last_cube_z,last_cube_w,last_cube_h)
        end
    end

    % Exit fix cube mode
    is_game_in_fix_cube_mode = false;
end

function insert_cube_to_game_occupied_matrix_duplicated(x,y,z,width_x,height_y, cube_color_str)
    % The function enter a cube to the board game.
    % Cubes values:
    %    1 - Yellow
    %    2 - White
    %    3 - Red
    %    4 - Blue
    %    5 - Black
    
    global game_occupied_matrix % board game
    
    % Convert the cube's color from str to number
    cube_color_num = color_str_to_color_num_duplicated(cube_color_str);
    
    % Set the cube's values in the 3D game board to be the cube's color num in the wanted coordinate (x,y,z)
    game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1) = cube_color_num .* ones([height_y width_x 1]);
    
end

function remove_cube_from_game_occupied_matrix_duplicated(x,y,z,width_x,height_y)
    % The function remove a cube from the board game
    
    global game_occupied_matrix % board game
    
    % Set the bouad value (the 3D cube) to be zeros in the wanted coordinate (x,y,z)
    game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1) = zeros([height_y width_x 1]);
    
end

function color_num = color_str_to_color_num_duplicated(color_str)
    % The function convert from color_str to color_num
    % The color values:
    %    1 - Yellow
    %    2 - White
    %    3 - Red
    %    4 - Blue
    %    5 - Black
    
    if color_str == "Empty"
        color_num = 0;
    elseif color_str == "yellow"
        color_num = 1;
    elseif color_str == "white"
        color_num = 2;
    elseif color_str == "red"
        color_num = 3;
    elseif color_str == "blue"
        color_num = 4;
    else
        color_num = 5;
    end

end

%% Buttons

function set_button_change_state(button_index, is_pressed)

    global is_game_in_fix_cube_mode
    global is_game_in_undoing_last_move_mode
    global freeze_tracking_model_mode

    global fix_cube_mode_axis_idx
    
    global fix_cube_mode_axis_options

    global is_waiting_to_reset_start_app
    
    global is_game_running

    switch is_pressed
        case true
            button_state = "Pressed";
        case false
            button_state = "Released";
    end
    disp("Button "+num2str(button_index)+" in state = "+button_state);
    new_data = "[Button,"+num2str(button_index)+","+button_state+"]";
    add_data_to_model_txt_descriptor(new_data);

    if (button_index == 1)
        if ~is_pressed
            if is_game_in_fix_cube_mode
                % Toggle dix dir
                fix_cube_mode_axis_idx = fix_cube_mode_axis_idx+1;
                if fix_cube_mode_axis_idx == 4
                    fix_cube_mode_axis_idx = 1;
                end
                disp("Fix dir = "+fix_cube_mode_axis_options(fix_cube_mode_axis_idx));
                new_data = "[Status,"+"Fix dir = "+fix_cube_mode_axis_options(fix_cube_mode_axis_idx)+"]";
                add_data_to_model_txt_descriptor(new_data);

            elseif freeze_tracking_model_mode
                % Clear model and re-track
                freeze_tracking_model_mode = false;
                disp("unfreeze tracking");
                new_data = "[Status,"+"Unfreeze tracking"+"]";
                add_data_to_model_txt_descriptor(new_data);
            end
        end
    elseif (button_index == 2)
        if ~is_pressed
            if is_game_in_fix_cube_mode
                % Shift left/up/forward
                switch fix_cube_mode_axis_options(fix_cube_mode_axis_idx)
                    case "LeftRight"
                        fix_last_cube_to_direction(1,0,0);
                    case "UpDown"
                        fix_last_cube_to_direction(0,1,0);
                    case "ForwardBackward"
                        fix_last_cube_to_direction(0,0,1);
                end  
            elseif freeze_tracking_model_mode
                % Clear model and re-track
                disp("clear model and unfreeze tracking");
                is_waiting_to_reset_start_app = true;
                freeze_tracking_model_mode = false;
                %is_game_running = false;

                % Reset game in unity
                new_data = "[RESET]";
                add_data_to_model_txt_descriptor(new_data);
            end
        end
    elseif (button_index == 3)
        if ~is_pressed
            if is_game_in_fix_cube_mode
                % Shift right/down/backward
                switch fix_cube_mode_axis_options(fix_cube_mode_axis_idx)
                    case "LeftRight"
                        fix_last_cube_to_direction(-1,0,0);
                    case "UpDown"
                        fix_last_cube_to_direction(0,-1,0);
                    case "ForwardBackward"
                        fix_last_cube_to_direction(0,0,-1);
                end  
            end
        end
    elseif (button_index == 4)    
        if ~is_pressed
             if is_game_in_fix_cube_mode
                % Undo last changed cube
                disp("selected undo last change in fix cube mode");
                new_data = "[Status,"+"Undo last change (15sec)"+"]";
                add_data_to_model_txt_descriptor(new_data);
                undo_last_changed_cube();
                disp("pause 15 sec");
                pause(15);
                new_data = "[Status,"+"Undo last change (waiting...)"+"]";
                add_data_to_model_txt_descriptor(new_data);
                disp("end pause 15 sec");
             elseif ~freeze_tracking_model_mode
                disp("enter freeze tracking, pause 30 sec");
                new_data = "[Status,"+"Freeze tracking (30sec)"+"]";
                add_data_to_model_txt_descriptor(new_data);
                freeze_tracking_model_mode = true;
                pause(30); % Let 30 sec to remove all cubes
                new_data = "[Status,"+"Freeze tracking (waiting...)"+"]";
                add_data_to_model_txt_descriptor(new_data);
                disp("finish pause 30 sec");
            end
        end
    elseif (button_index == 5)   
        % Toggle "Fix cube" mode
        if ~is_pressed
            if freeze_tracking_model_mode
                % Clear model and re-track
                % Dont reset game
                disp("clear model and unfreeze tracking");
                is_waiting_to_reset_start_app = true;
                freeze_tracking_model_mode = false;
                new_data = "[Status,"+"Clear model"+"]";
                add_data_to_model_txt_descriptor(new_data);
                
            elseif ~is_game_in_fix_cube_mode && ~is_game_in_undoing_last_move_mode
                % Enter fix cube mode
                disp("enter fix cube mode");
                enter_fix_cube_mode();
                new_data = "[Status,"+"Enter fix cube mode"+"]";
                add_data_to_model_txt_descriptor(new_data);
            elseif is_game_in_fix_cube_mode && ~is_game_in_undoing_last_move_mode
                % Exit fix cube mode
                disp("exit fix cube mode (manual shifting cube)");
                exit_fix_cube_mode();
                new_data = "[Status,"+"Exit fix cube mode"+"]";
                add_data_to_model_txt_descriptor(new_data);
            elseif is_game_in_undoing_last_move_mode
                % Apply undoing last change in board
                disp("apply undoing last change");
                apply_undoing_last_changed_cube();
                new_data = "[Status,"+"Apply undoing last change"+"]";
                add_data_to_model_txt_descriptor(new_data);
             
            end
        end
    end
    
end
