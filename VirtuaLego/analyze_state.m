function [cube_change_detected, cube_status_add_or_sub, lego_grid_x, lego_grid_y, lego_grid_z, lego_grid_width, lego_grid_height, lego_cube_color] = analyze_state(cur_top_org, prev_top_org, cur_left_org, prev_left_org, cur_right_org, prev_right_org, cur_back_org, prev_back_org)
    % The function gets 4 images (4Xcur, 4X prev - 4 for cameras
    % top,left,right,back)
    % The function returns [x,y,z,width,height,color] of the cube
    % and a flag indicating if new cube is detected (the
    % [x,y,z,width,height,color] values are relevant only if
    % is_new_cube=true)

    global app_state
    app_state = "Analyze state";
    disp(["App state: ",app_state]);

    global has_cubes_on_board
    global was_last_action_addition
    global last_cube_x last_cube_y last_cube_z last_cube_w last_cube_h last_cube_color 
    global game_occupied_matrix game_occupied_matrix_prev_state
    
    % Flag to mark mismatches
    detected_mismatch_in_cube = false;

    % ---- Reset to default values -------------------------------
    cube_change_detected = false;
    cube_status_add_or_sub = 0;
    lego_grid_x = 0;
    lego_grid_y = 0;
    lego_grid_z = 0;
    lego_grid_width = 0;
    lego_grid_height = 0;
    lego_cube_color = "Empty";

    % ------- Debug plot binary map flags ------------------------
    
    debug_plot_binary_map_top_first = true;
    debug_plot_binary_map_top_reprediction = true;
    debug_plot_binary_map_xy_from_side = true;
    debug_plot_binary_map_z_from_side = true;


    % ---- Normalize images ---------------------------------------
    cur_top_org = normalize_image(cur_top_org);
    cur_left_org = normalize_image(cur_left_org);
    cur_right_org = normalize_image(cur_right_org);
    cur_back_org = normalize_image(cur_back_org);
    prev_top_org = normalize_image(prev_top_org);
    prev_left_org = normalize_image(prev_left_org);
    prev_right_org = normalize_image(prev_right_org);
    prev_back_org = normalize_image(prev_back_org);

    % ---- Geometrical transformations -----------------------------

    % Load the geometrical transformations for strighting the images
    img_tforms = load_geometrical_transformation();
    [left_cam_anchors,right_cam_anchors,back_cam_anchors] = load_side_images_corners_coordinates();

    prev_top = top_image_geometrical_transformation(img_tforms.top_img_tform,prev_top_org);
    cur_top = top_image_geometrical_transformation(img_tforms.top_img_tform,cur_top_org);
    prev_left = side_image_geometrical_transformation(img_tforms.left_img_tform,prev_left_org);
    cur_left = side_image_geometrical_transformation(img_tforms.left_img_tform,cur_left_org);
    prev_right = side_image_geometrical_transformation(img_tforms.right_img_tform,prev_right_org);
    cur_right = side_image_geometrical_transformation(img_tforms.right_img_tform,cur_right_org);
    prev_back = side_image_geometrical_transformation(img_tforms.back_img_tform,prev_back_org);
    cur_back = side_image_geometrical_transformation(img_tforms.back_img_tform,cur_back_org);

    %{
    figure;
    subplot(1,2,1);
    imshow(prev_top);
    title("prev image");
    subplot(1,2,2);
    imshow(cur_top);
    title("cur image");
    %}


    % ----------------------------------------------------

    [left_binary_mask, right_binary_mask, back_binary_mask] = generate_sides_binary_mask();

    %images_diff_binary_map(prev_left,cur_left);

    % Get the estimated [x,y,width,height] of the cube
    % Estimate without color filtering
    [detected_new_cube_top_cam, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height, predicted_color_from_top] = get_lego_grid_xy(cur_top,prev_top,debug_plot_binary_map_top_first);
    cube_change_detected = detected_new_cube_top_cam;

    % If cube detected from top camera,
    % check if the detected color (the binary map with the largest area)
    % has the same color of standart color sampling
    if cube_change_detected

        %disp("XY using top");
        % Get the color of the cube
        lego_cube_color = get_color_of_cube(cur_top, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height);

        if lego_cube_color ~= predicted_color_from_top
            disp("color from top cam mismatch: from detect xy = "+predicted_color_from_top+" , sampled = "+lego_cube_color);
            detected_mismatch_in_cube = true;
            cube_change_detected = false;
        end     
    end

    if ~cube_change_detected

        disp("coulnt find a cube from top. look for partial cube");

        % Look for partial-cube case (cube that is overlapped with cube in the same color)
        [detected_partial_cube, lego_partial_grid_x, lego_partial_grid_y, lego_partial_grid_width, lego_partial_grid_height] = get_partial_cube_detection(cur_top,prev_top,"Empty");

        % The partial-cube case is not relevant if this is the first cubes floor
        if detected_partial_cube
            % If detected partial cube, check if in the neighbors there are
            % cubes in the same color

            % Check color of partial-cube
            partial_cube_color = get_color_of_cube(cur_top, lego_partial_grid_x, lego_partial_grid_y, lego_partial_grid_width, lego_partial_grid_height);

            % Check neighbors (if exist) colors
   
            if (lego_partial_grid_width == 4 && lego_partial_grid_height == 1) || ...
               (lego_partial_grid_width == 1 && lego_partial_grid_height == 4) || ...
               (lego_partial_grid_width == 2 && lego_partial_grid_height == 2)

               disp(["particl cube","X=",lego_partial_grid_x,"Y=",lego_partial_grid_y,"Width=",lego_partial_grid_width,"Height=",lego_partial_grid_height]);

               [detected_full_from_partial_cube, lego_dtct_grid_x, lego_dtct_grid_y, lego_dtct_grid_width, lego_dtct_grid_height] = get_location_for_rest_of_cube(lego_partial_grid_x, lego_partial_grid_y, lego_partial_grid_width, lego_partial_grid_height, partial_cube_color);

               if detected_full_from_partial_cube
                    cube_change_detected = true;
                    lego_grid_x = lego_dtct_grid_x;
                    lego_grid_y = lego_dtct_grid_y;
                    lego_grid_width = lego_dtct_grid_width;
                    lego_grid_height = lego_dtct_grid_height;
                    lego_cube_color = partial_cube_color;
                    disp("detected cube from partial");
               end
            end
 
        end
        
    end

    if ~cube_change_detected
        disp("XY using sides");
        % If couldnt identify [x,y,w,h] from top cam, try from side cams
        [detected_new_cube_side_cams, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height, lego_predicted_color] = get_lego_grid_xy_from_sides_cameras(cur_left,...
                                                                                                                                        prev_left,...
                                                                                                                                        cur_right,...
                                                                                                                                        prev_right,...
                                                                                                                                        cur_back,...
                                                                                                                                        prev_back, ...
                                                                                                                                        lego_grid_x, ...
                                                                                                                                        left_cam_anchors, ...
                                                                                                                                        right_cam_anchors, ...
                                                                                                                                        back_cam_anchors,...
                                                                                                                                        left_binary_mask,...
                                                                                                                                        right_binary_mask,...
                                                                                                                                        back_binary_mask,...
                                                                                                                                        debug_plot_binary_map_xy_from_side);
        
        
        cube_change_detected = detected_new_cube_side_cams;

        % If cube detected now, calculate cube color
        if detected_new_cube_side_cams
            % Get the color of the cube, after predicted [x,y,w,h] from
            % side cams
            lego_cube_color = get_color_of_cube(cur_top, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height);

            % Compare color from side cams to color from top cam using side
            % coordinates predictions
            if lego_cube_color ~= lego_predicted_color
                disp("Side prediction failed - colors from side and top don't match");
                cube_change_detected = false;
                detected_mismatch_in_cube = true;
            end
        end
    end


    if cube_change_detected

        % Decide if the new cube is addition or subtraction using colors:
        detected_addition_subtraction_using_top_only = false;
        highest_z_in_xy = get_highest_occupied_z_in_coordinates(lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height);

        if highest_z_in_xy ~= -1 % No error or mixed colors in the cube coordinates
            % Check for 4 cases that we can set addition/removal using
            % colors only
            if highest_z_in_xy == 0
                if lego_cube_color ~= "ground_color"
                    % If a non-ground color detected on ground color,
                    % this is a new added cube
                    detected_addition_subtraction_using_top_only = true;
                    lego_grid_z = 0; % Add cube in z=0
                    cube_status_add_or_sub = 1; % Addition
                end
            else % highest_z_in_xy >= 1
                cur_highest_color = get_color_of_cube_in_coordinates(lego_grid_x, lego_grid_y, highest_z_in_xy-1, lego_grid_width, lego_grid_height);
                if cur_highest_color == "MixedColors"
                    % If in the cube cooredinates there is a mix of few
                    % colors, it can't be removal.
                    % therefore, this is a new added cube
                    detected_addition_subtraction_using_top_only = true;
                    lego_grid_z = highest_z_in_xy;
                    cube_status_add_or_sub = 1; % Addition
                else
                    if highest_z_in_xy == 1
                        if lego_cube_color == "ground_color"
                            % If a ground color gray detected on top of exist cube,
                            % this in removal of this cube
                            detected_addition_subtraction_using_top_only = true;
                            lego_grid_z = 0; % Remove cube in z=0
                            cube_status_add_or_sub = -1; % Removal
                        end
                    end
                    if ~detected_addition_subtraction_using_top_only % highest_z_in_xy >= 1
                        if highest_z_in_xy-2 >= 0
                            cube_below_color = get_color_of_cube_in_coordinates(lego_grid_x, lego_grid_y, highest_z_in_xy-2, lego_grid_width, lego_grid_height);
                        else
                            cube_below_color = "ground_color";
                        end
                        if cube_below_color ~= "Empty" % Not empty coordinates
                            if lego_cube_color ~= cube_below_color
                                % If a color which is different then the below-the-last
                                % color detected, this can't be a removal. 
                                % therefore, this is a new added cube
                                detected_addition_subtraction_using_top_only = true;
                                lego_grid_z = highest_z_in_xy;
                                cube_status_add_or_sub = 1; % Addition
                            end
                        end
                    end
                end
            end
        end



        % If could not detect using colors, detect using z estimation from
        % side cameras
        %{
        if ~detected_addition_subtraction_using_top_only
            disp("Detected using side cameras");
        else
            disp("Side camera for debug only");
            detected_addition_subtraction_using_top_only = false;
        end
        %}

        if ~detected_addition_subtraction_using_top_only
            disp("Detected z using side cameras");
            min_grid_z = max(highest_z_in_xy-1,0);
            max_grid_z = highest_z_in_xy + 1;

            % Get the estimated [z] of the cube
            lego_grid_z = get_lego_grid_z(cur_left,...
                                            prev_left,...
                                            cur_right,...
                                            prev_right,...
                                            cur_back,...
                                            prev_back, ...
                                            lego_grid_x, ...
                                            lego_grid_y, ...
                                            lego_grid_width, ...
                                            lego_grid_height, ... 
                                            min_grid_z,...
                                            max_grid_z,...
                                            lego_cube_color,...
                                            left_cam_anchors, ...
                                            right_cam_anchors, ...
                                            back_cam_anchors,...
                                            left_binary_mask,...
                                            right_binary_mask,...
                                            back_binary_mask,...
                                            debug_plot_binary_map_z_from_side);
    
            cube_status_add_or_sub = check_for_addition_or_subtraction_of_cube(lego_grid_x,lego_grid_y,lego_grid_z,lego_grid_width,lego_grid_height);
        
            %{
        else
            disp("Detected using top only [side check for debug only]");
            % Only for debug

            min_grid_z = 0;
            max_grid_z = 5;

            get_lego_grid_z(cur_left,...
                            prev_left,...
                            cur_right,...
                            prev_right,...
                            cur_back,...
                            prev_back, ...
                            lego_grid_x, ...
                            lego_grid_y, ...
                            lego_grid_width, ...
                            lego_grid_height, ...
                            min_grid_z,...
                            max_grid_z,...
                            lego_cube_color,...
                            left_cam_anchors, ...
                            right_cam_anchors, ...
                            back_cam_anchors,...
                            left_binary_mask,...
                            right_binary_mask,...
                            back_binary_mask);
            %}
        end

        

        % Create backup in case of fixing cube 
            
        last_cube_x = lego_grid_x;
        last_cube_y = lego_grid_y;
        last_cube_z = lego_grid_z;
        last_cube_w = lego_grid_width;
        last_cube_h = lego_grid_height;
        last_cube_color = lego_cube_color;
        game_occupied_matrix_prev_state = game_occupied_matrix;

        if cube_status_add_or_sub == 1 % Addition
            % Add new cube to the occupied game matrix
            has_cubes_on_board = true;
            was_last_action_addition = true;
            insert_cube_to_game_occupied_matrix(lego_grid_x,lego_grid_y,lego_grid_z,lego_grid_width,lego_grid_height,lego_cube_color);
        elseif cube_status_add_or_sub == -1 % Remove cube
            % Remove cube from the occupied game matrix
            was_last_action_addition = false;
            remove_cube_from_game_occupied_matrix(lego_grid_x,lego_grid_y,lego_grid_z,lego_grid_width,lego_grid_height);
        end

    end
   
end

%% Functions - Normal behavior

function binary_map = images_diff_binary_map(prev_img, cur_img, map_mask, keep_only_largest_area)
    % The function gets 3 parameters:
    %   2 GRB images - one of the current state of the 
    %   system and one from the previous state.
    %   1 Binary map for masking the interest areas
    % The function return the changes between both states as a binary map
    
    % Subtract both state to find the differences
    sub_images = cur_img - prev_img;
    
    % Combain the changes in the RGB channels
    sum_abs_cnl = abs(sub_images(:,:,1)) + abs(sub_images(:,:,2)) + abs(sub_images(:,:,3));
    sum_abs_cnl = sum_abs_cnl/max(sum_abs_cnl(:)); % Normalized
    
    binary_tresh_param_values = [0.2];
    bwareaopen_param_values = [200];

    is_found_area = false;

    for i=1:length(binary_tresh_param_values)

        binary_tresh_param = binary_tresh_param_values(i);
        bwareaopen_param = bwareaopen_param_values(i);
        % Create a binary map of the changes
        bin_diff = imbinarize(sum_abs_cnl,binary_tresh_param);

        if ~isempty(map_mask)
            bin_diff = bin_diff.*map_mask;
        end

        bin_diff_cleaned = bwareaopen(bin_diff,bwareaopen_param); % Removed small changes in the binary map (noise)
        
        % Recognize the cube in the binary map (distinguish between it and other white area)
        stats = regionprops(bin_diff_cleaned, 'Area', 'BoundingBox', 'Image'); % Find all the white objects in the map

        if ~isempty(stats)
            is_found_area = true;
            %disp("binary map - detected in high params");
            break;
        end
    end

    if keep_only_largest_area
        if ~is_found_area
            binary_map = zeros(size(bin_diff_cleaned));
            %disp("Didn't find area in binary map");
        else
        
        
            % Select the cube between all objects (the object with the largest area)
            [~,cube_index] = max( [stats.Area]);
            
            % Set the cube bounding box parameters
            x_cube = round(stats(cube_index).BoundingBox(1));
            y_cube = round(stats(cube_index).BoundingBox(2));
            width_cube = round(stats(cube_index).BoundingBox(3));
            height_cube = round(stats(cube_index).BoundingBox(4));
            
            % initiate the binary map
            binary_map = zeros(size(bin_diff_cleaned));
            % Place the cube in the binary map
            binary_map(y_cube:y_cube+height_cube-1 , x_cube:x_cube+width_cube-1) = stats(cube_index).Image;
        end
    else
        binary_map = bin_diff_cleaned;
    end
    
end

function ret_img = normalize_image(img)
    ret_img = double(img)/255;
end

function [detected_new_cube, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height, cube_color] = get_lego_grid_xy(cur_img,prev_img, debug_plot_binary_map)
    % The function gets an image and estimates the [x,y,width,height] of
    % the lego cube in xy.

    global cam_height cam_width
    
    top_img_grid_resolution=20;
    area_lower_treshold_to_detect_cube = 2000;
    area_upper_treshold_to_detect_cube = 8000;
    
    optional_colors = ["red","blue","yellow","white","ground_color"];
    amount_of_colors = length(optional_colors);
    binary_map_area_result_arr = zeros(1,amount_of_colors);

    % calc the binary map of the new cube for each color
    for loop_color_idx = 1:amount_of_colors
        loop_color_name = optional_colors(loop_color_idx);
        color_binary_map = get_color_filtered_binary_map(cur_img,loop_color_name,"top");
        binary_map = images_diff_binary_map(prev_img, cur_img,color_binary_map,true);

        stats = regionprops(binary_map, 'BoundingBox', 'Centroid', 'Area');
        if ~isempty(stats) && stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube
            binary_map_area_result_arr(loop_color_idx) = stats.Area;
        end
    end

    % Select the color with the highest area
    [~,selected_color_index] = max(binary_map_area_result_arr);
    cube_color = optional_colors(selected_color_index);

    if cube_color ~= "ground_color"
        color_binary_map = get_color_filtered_binary_map(cur_img,cube_color,"top");
    else
        % In case of detection of ground color
        % Look for the color of cube in prev_img
        % for detection of [x,y,w,h]
        prev_img_binary_map_area_result_arr = zeros(1,amount_of_colors);

        % calc the binary map of the new cube for each color
        for loop_color_idx = 1:amount_of_colors
            loop_color_name = optional_colors(loop_color_idx);
            color_binary_map = get_color_filtered_binary_map(prev_img,loop_color_name,"top");
            binary_map = images_diff_binary_map(prev_img, cur_img,color_binary_map,true);
    
            stats = regionprops(binary_map, 'BoundingBox', 'Centroid', 'Area');
            if ~isempty(stats) && stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube
                prev_img_binary_map_area_result_arr(loop_color_idx) = stats.Area;
            end
        end

        % Select the color with the highest area
        [~,selected_color_index] = max(prev_img_binary_map_area_result_arr);
        cube_color_of_prev_cube = optional_colors(selected_color_index);

        % Create the color_binary_map from prev_img
        color_binary_map = get_color_filtered_binary_map(prev_img,cube_color_of_prev_cube,"top");
    end

    binary_map = images_diff_binary_map(prev_img, cur_img,color_binary_map,true);

    % Calc automaticlly the center of mass and the bounding box
    stats = regionprops(binary_map, 'BoundingBox', 'Centroid', 'Area');
    
    % Check if detected area is above treshold
    if ~isempty(stats) && stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube
        % Detect cube from top camera    
        %-------------------------- Bounding ----------------------------------
        if stats.BoundingBox(3) > stats.BoundingBox(4)
            lego_grid_width = 4;
            lego_grid_height = 2;
        else
            lego_grid_width = 2;
            lego_grid_height = 4;
        end

        %--------------------------- Center -----------------------------------    
        % Center of mass (automaticlly computation)
        x_center_auto = round(stats.Centroid(1));
        y_center_auto = round(stats.Centroid(2));

        % Set a 1D array to save the amount of ones in each row in the 2D board
        ones_for_each_row = sum(binary_map, 2); % size = row_num*1

        % Set a 1D array to save the amount of ones in each column in the 2D board
        ones_for_each_col = sum(binary_map, 1); % size = col_num*1

        % diff vector for the rows
        diff_row = ones_for_each_row(2:end) - ones_for_each_row(1:end-1);

        % diff vector for the col
        diff_col = ones_for_each_col(2:end) - ones_for_each_col(1:end-1);

        % find the 2 places in the row vector with the maximum
        % values (the places with maximum change) from left and rigth to the
        % center of mass    
        [max_value_row, max_index_row] = max(diff_row(1:y_center_auto));
        [min_value_row, min_index_row] = min(diff_row(y_center_auto+1:end));
        min_index_row = min_index_row + y_center_auto;
        % find the 2 places in the col vector with the maximum abs value
        [max_value_col, max_index_col] = max(diff_col(1:x_center_auto));
        [min_value_col, min_index_col] = min(diff_col(x_center_auto+1:end));
        min_index_col = min_index_col + x_center_auto;

        % Hanlde pixels on edges
        if ones_for_each_row(1) > abs(max_value_row)
            max_value_row = ones_for_each_row(1);
            max_index_row = 1;
        end
        if ones_for_each_row(cam_height) > abs(min_value_row)
            min_value_row = ones_for_each_row(cam_height);
            min_index_row = cam_height;
        end
        if ones_for_each_col(1) > abs(max_value_col)
            max_value_col = ones_for_each_col(1);
            max_index_col = 1;
        end
        if ones_for_each_col(cam_height) > abs(min_value_col)
            min_value_col = ones_for_each_col(cam_height);
            min_index_col = cam_height;
        end

        % Top and bottom edges
        if abs(max_value_row) > abs(min_value_row) % Detect the top edge
            lego_grid_y = round(abs(max_index_row)/top_img_grid_resolution);
        else % Detect the bottom edge
            lego_grid_y = round(abs(min_index_row)/top_img_grid_resolution) - lego_grid_height;
        end

        % left and rigth edges
        if abs(max_value_col) > abs(min_value_col) % Detect the top edge
            lego_grid_x = round(abs(max_index_col)/top_img_grid_resolution);
        else % Detect the bottom edge
            lego_grid_x = round(abs(min_index_col)/top_img_grid_resolution) - lego_grid_width;
        end
        
        detected_new_cube = true;

        
    else
        % Didn't detect cube from top camera
        lego_grid_x = 0;
        lego_grid_y = 0;
        lego_grid_width = 0;
        lego_grid_height = 0;
        detected_new_cube = false;
        
        if isempty(stats) || (stats.Area < area_lower_treshold_to_detect_cube)
            disp("Top camera detect too SMALL area to be a cube");
        else
            disp("Top camera detect too LARGE area to be a cube");
        end
    end

    if debug_plot_binary_map
        figure;
        subplot(1,3,1);
        imshow(binary_map);
        if cube_color == "Empty"
            title("binary map - top (first)");
        else
            title("binary map - top (re-prediction with color = "+cube_color+")");
        end
        subplot(1,3,2);
        imshow(prev_img);
        subplot(1,3,3);
        imshow(cur_img);
    end
        
end

function lego_grid_z = get_lego_grid_z(cur_left, prev_left, cur_right, prev_right, cur_back, prev_back, cube_grid_x, cube_grid_y, cube_grid_width, cube_grid_height, min_grid_z, max_grid_z, cube_color, left_cam_anchors, right_cam_anchors, back_cam_anchors, left_binary_mask, right_binary_mask, back_binary_mask, debug_plot_binary_map)
    % Estimate the z component (on lego grid) of the cube

    global grid_size;

    % Calculate the grid corners of the cube
    cube_grid_x_left = cube_grid_x;
    cube_grid_x_right = cube_grid_x + cube_grid_width;
    cube_grid_y_top = cube_grid_y;
    cube_grid_y_bottom = cube_grid_y + cube_grid_height;

    left_cam_free_los = get_if_free_line_of_sight(cube_grid_x,cube_grid_y,min_grid_z,max_grid_z,cube_grid_width,cube_grid_height,"left");
    right_cam_free_los = get_if_free_line_of_sight(cube_grid_x,cube_grid_y,min_grid_z,max_grid_z,cube_grid_width,cube_grid_height,"right");
    back_cam_free_los = get_if_free_line_of_sight(cube_grid_x,cube_grid_y,min_grid_z,max_grid_z,cube_grid_width,cube_grid_height,"back");


    left_cam_weight = (1-(cube_grid_x/grid_size))*0.5 + 0.5;
    right_cam_weight = (cube_grid_x/grid_size)*0.5 + 0.5;
    back_cam_weight = (1-(cube_grid_y/grid_size))*0.5 + 0.5;

    total_z_prediction = 0;
    total_z_sum = 0;

    debug_str = "";

    if left_cam_free_los
        [valid_left_z,lego_grid_z_from_left_direction] = get_lego_grid_z_from_direction(prev_left, cur_left,cube_grid_x_left,cube_grid_x_right,cube_grid_y_top,cube_grid_y_bottom,min_grid_z,max_grid_z,cube_color,"left",left_cam_anchors, left_binary_mask, debug_plot_binary_map);
        if valid_left_z
            total_z_prediction = total_z_prediction + left_cam_weight*lego_grid_z_from_left_direction;
            total_z_sum = total_z_sum + left_cam_weight;
            debug_str = debug_str + "[left: pred="+num2str(lego_grid_z_from_left_direction)+", weight="+num2str(left_cam_weight)+"]";
        end
        else
        debug_str = debug_str + "[left no los]";
    end
    if right_cam_free_los
        [valid_right_z,lego_grid_z_from_right_direction] = get_lego_grid_z_from_direction(prev_right, cur_right,cube_grid_x_left,cube_grid_x_right,cube_grid_y_top,cube_grid_y_bottom,min_grid_z,max_grid_z,cube_color,"right",right_cam_anchors, right_binary_mask, debug_plot_binary_map);
        if valid_right_z
            total_z_prediction = total_z_prediction + right_cam_weight*lego_grid_z_from_right_direction;
            total_z_sum = total_z_sum + right_cam_weight;
            debug_str = debug_str + "[right: pred="+num2str(lego_grid_z_from_right_direction)+", weight="+num2str(right_cam_weight)+"]";
        end
    else
        debug_str = debug_str + "[right no los]";
    end
    if back_cam_free_los
        [valid_back_z,lego_grid_z_from_back_direction] = get_lego_grid_z_from_direction(prev_back, cur_back,cube_grid_x_left,cube_grid_x_right,cube_grid_y_top,cube_grid_y_bottom,min_grid_z,max_grid_z,cube_color,"back",back_cam_anchors, back_binary_mask, debug_plot_binary_map);
        if valid_back_z
            total_z_prediction = total_z_prediction + back_cam_weight*lego_grid_z_from_back_direction;
            total_z_sum = total_z_sum + back_cam_weight;
            debug_str = debug_str + "[back: pred="+num2str(lego_grid_z_from_back_direction)+", weight="+num2str(back_cam_weight)+"]";
        end
    else
        debug_str = debug_str + "[back no los]";
    end

    lego_grid_z = round(total_z_prediction/total_z_sum);
    debug_str = "z prediction using sides = "+num2str(lego_grid_z)+" << "+debug_str;

    disp(debug_str);
    %disp("Left z: "+num2str(lego_grid_z_from_left_direction)+", Right z: "+num2str(lego_grid_z_from_right_direction)+", Back z: "+num2str(lego_grid_z_from_back_direction))

end

function [valid_z,lego_grid_z_from_direction] = get_lego_grid_z_from_direction(prev_img, cur_img, cube_grid_x_left,cube_grid_x_right,cube_grid_y_top,cube_grid_y_bottom, min_grid_z, max_grid_z, cube_color, cam_side, cam_anchors, cam_binary_mask, debug_plot_binary_map)
    
    global grid_size

    % Generate binary image
    color_binary_mask = get_color_filtered_binary_map(cur_img,cube_color,cam_side);

    coord_based_binary_map = get_coordinates_based_binary_map(cube_grid_x_left,cube_grid_x_right,cube_grid_y_top,cube_grid_y_bottom,min_grid_z, max_grid_z, cam_side,cam_anchors);

    binary_map = images_diff_binary_map(prev_img, cur_img, cam_binary_mask .* color_binary_mask .* coord_based_binary_map,true);



    stats = regionprops(binary_map,'BoundingBox','Centroid');

    if isempty(stats)
        valid_z = false;
        lego_grid_z_from_direction = -1;
    else
        valid_z = true;

        y_cube = round(stats.BoundingBox(2));
        height_cube = round(stats.BoundingBox(4));
        lowest_y_pixel = y_cube + height_cube - 1;

        center_mass_y_pixel = round(stats.Centroid(2));
    
    
        % Calculate strimated y pixel coordinate for the zero height in the
        % cube x-y grid position:
    
        if cam_side == "left"
    
            % Cube grid locations
            relative_x_grid = (cube_grid_x_left - cam_anchors.back_left.grid_x) / (cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
            cube_grid_y = (cube_grid_y_top + cube_grid_y_bottom)/2;
            relative_cube_grid_y = cube_grid_y/grid_size;
    
            % Calculate y of cube
            y_of_cube_line_left_edge = cam_anchors.back_left.y + relative_x_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);
            y_of_cube_line_right_edge = cam_anchors.front_left.y + relative_x_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);
            y_of_cube_line = y_of_cube_line_left_edge + relative_cube_grid_y*(y_of_cube_line_right_edge - y_of_cube_line_left_edge);
            y_of_base_height = y_of_cube_line;
            
    
            % Calculate z-unit in cube pos
            z_unit_of_cube_line_left_edge = cam_anchors.back_left.z_unit + relative_x_grid*(cam_anchors.back_right.z_unit - cam_anchors.back_left.z_unit);
            z_unit_of_cube_line_right_edge = cam_anchors.front_left.z_unit + relative_x_grid*(cam_anchors.front_right.z_unit - cam_anchors.front_left.z_unit);
    
            z_unit_of_cube_line = z_unit_of_cube_line_left_edge + relative_cube_grid_y*(z_unit_of_cube_line_right_edge - z_unit_of_cube_line_left_edge);
            z_unit_in_cube_dist = z_unit_of_cube_line;
    
        elseif cam_side == "right"
            
            % Cube grid locations
            relative_x_grid = (cube_grid_x_right - cam_anchors.back_left.grid_x) / (cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
            cube_grid_y = (cube_grid_y_top + cube_grid_y_bottom)/2;
            relative_cube_grid_y = cube_grid_y/grid_size;
    
            % Calculate y of cube
            y_of_cube_line_left_edge = cam_anchors.back_left.y + relative_x_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);
            y_of_cube_line_right_edge = cam_anchors.front_left.y + relative_x_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);
            y_of_cube_line = y_of_cube_line_left_edge + relative_cube_grid_y*(y_of_cube_line_right_edge - y_of_cube_line_left_edge);
            y_of_base_height = y_of_cube_line;
            
    
            % Calculate z-unit in cube pos
            z_unit_of_cube_line_right_edge = cam_anchors.back_left.z_unit + relative_x_grid*(cam_anchors.back_right.z_unit - cam_anchors.back_left.z_unit);
            z_unit_of_cube_line_left_edge = cam_anchors.front_left.z_unit + relative_x_grid*(cam_anchors.front_right.z_unit - cam_anchors.front_left.z_unit);
    
            z_unit_of_cube_line = z_unit_of_cube_line_right_edge + relative_cube_grid_y*(z_unit_of_cube_line_left_edge - z_unit_of_cube_line_right_edge);
            z_unit_in_cube_dist = z_unit_of_cube_line;
    
         elseif cam_side == "back"
            
            % Cube grid locations
            relative_y_grid = (cube_grid_y_top - cam_anchors.back_left.grid_y) / (cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
            cube_grid_x = (cube_grid_x_left + cube_grid_x_right)/2;
            relative_cube_grid_x = cube_grid_x/grid_size;
    
            % Calculate y of cube
            y_of_cube_line_left_edge = cam_anchors.back_right.y + relative_y_grid*(cam_anchors.front_right.y - cam_anchors.back_right.y);
            y_of_cube_line_right_edge = cam_anchors.back_left.y + relative_y_grid*(cam_anchors.front_left.y - cam_anchors.back_left.y);
            y_of_cube_line = y_of_cube_line_right_edge + relative_cube_grid_x*(y_of_cube_line_left_edge - y_of_cube_line_right_edge);
            y_of_base_height = y_of_cube_line;
            
    
            % Calculate z-unit in cube pos
            z_unit_of_cube_line_left_edge = cam_anchors.back_right.z_unit + relative_y_grid*(cam_anchors.front_right.z_unit - cam_anchors.back_right.z_unit);
            z_unit_of_cube_line_right_edge = cam_anchors.back_left.z_unit + relative_y_grid*(cam_anchors.front_left.z_unit - cam_anchors.back_left.z_unit);
    
            z_unit_of_cube_line = z_unit_of_cube_line_right_edge + relative_cube_grid_x*(z_unit_of_cube_line_left_edge - z_unit_of_cube_line_right_edge);
            z_unit_in_cube_dist = z_unit_of_cube_line;
    
        end
    
        % Estimate height using most bottom pixel
        %{
        z_units = 10;
        z_unit_heights = ones(1,z_units)*y_of_base_height - (0:z_units-1).*z_unit_in_cube_dist;
        y_lowest_pixels_arr = ones(1,z_units)*lowest_y_pixel;
        diff_from_y_lower_pixel_arr = abs(y_lowest_pixels_arr - z_unit_heights);
        [~,estimated_z] = min(diff_from_y_lower_pixel_arr) ;
        lego_grid_z_from_direction = estimated_z-1; % From 1... z_unit to 0....z_unit-1
        %}

        % Estimate height using center of mass pixel
        z_units = 10;
        z_unit_heights = ones(1,z_units)*y_of_base_height - z_unit_in_cube_dist/2 - (0:z_units-1).*z_unit_in_cube_dist;
        y_center_mass_pixels_arr = ones(1,z_units)*center_mass_y_pixel;
        diff_from_y_center_mass_pixel_arr = abs(y_center_mass_pixels_arr - z_unit_heights);
        [~,estimated_z] = min(diff_from_y_center_mass_pixel_arr) ;
        lego_grid_z_from_direction = estimated_z-1; % From 1... z_unit to 0....z_unit-1
    

        %  --- Plot prev,cur and binary with height lines from side image ----------
        if debug_plot_binary_map
            z_unit_heights_floor_base = ones(1,z_units)*y_of_base_height - (0:z_units-1).*z_unit_in_cube_dist;
            figure;
            subplot(2,3,1);
            imshow(binary_map);
            for z_unit_idx = 1:z_units
                line([0 640],[z_unit_heights_floor_base(z_unit_idx) z_unit_heights_floor_base(z_unit_idx)]);
            end
            title(cam_side);
            subplot(2,3,2);
            imshow(prev_img);
            subplot(2,3,3);
            imshow(cur_img);
            subplot(2,3,4);
            imshow(color_binary_mask);
            for z_unit_idx = 1:z_units
                line([0 640],[z_unit_heights_floor_base(z_unit_idx) z_unit_heights_floor_base(z_unit_idx)]);
            end
            title("color binary mask");
            subplot(2,3,5);
            imshow(coord_based_binary_map);
            for z_unit_idx = 1:z_units
                line([0 640],[z_unit_heights_floor_base(z_unit_idx) z_unit_heights_floor_base(z_unit_idx)]);
            end
            title("coord based binary map");
        end
        % --------------------------------------------------------------------------

    end
end

function coord_binary_map = get_coordinates_based_binary_map(cube_grid_x_left,cube_grid_x_right,cube_grid_y_top,cube_grid_y_bottom,min_grid_z, max_grid_z, cam_side,cam_anchors)
    % The function gets the 4 x,y edges values (left x, right x, top y,
    % bottom y), the cam side and the cam anchors
    % The function returns a binary map of a cube
    % where pix=1 if left_lim <= x <= right_lim
    % and bot_lim <= y <= top_lim
    

    global cam_width cam_height

    % Set [x_left_lim,x_right_lim,y_bot_lim,y_top_lim] by camera and
    % coordinates
    if cam_side == "left"

        relative_x_grid = (cube_grid_x_left - cam_anchors.back_left.grid_x) / (cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);

        relative_top_y_grid = (cube_grid_y_top - cam_anchors.back_left.grid_y)/(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
        relative_bottom_y_grid = (cube_grid_y_bottom - cam_anchors.back_left.grid_y)/(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);

        % Calculate x of cube
        x_of_cube_line_left_board = cam_anchors.back_left.x + relative_x_grid*(cam_anchors.back_right.x - cam_anchors.back_left.x);
        x_of_cube_line_right_board = cam_anchors.front_left.x + relative_x_grid*(cam_anchors.front_right.x - cam_anchors.front_left.x);

        cube_top_x_pix = x_of_cube_line_left_board + relative_top_y_grid*(x_of_cube_line_right_board - x_of_cube_line_left_board);
        cube_bottom_x_pix = x_of_cube_line_left_board + relative_bottom_y_grid*(x_of_cube_line_right_board - x_of_cube_line_left_board);
        
        x_left_lim = cube_top_x_pix;
        x_right_lim = cube_bottom_x_pix;

        % Calculate z-unit mask
        y_of_cube_line_left_board = cam_anchors.back_left.y + relative_x_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);
        y_of_cube_line_right_board = cam_anchors.front_left.y + relative_x_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);

        relative_middle_y_grid = (relative_top_y_grid + relative_bottom_y_grid)/2;
        cube_base_y_pix = y_of_cube_line_left_board + relative_middle_y_grid*(y_of_cube_line_right_board - y_of_cube_line_left_board);

        % Calculate z-unit in cube pos
        z_unit_of_cube_line_left_board = cam_anchors.back_left.z_unit + relative_x_grid*(cam_anchors.back_right.z_unit - cam_anchors.back_left.z_unit);
        z_unit_of_cube_line_right_board = cam_anchors.front_left.z_unit + relative_x_grid*(cam_anchors.front_right.z_unit - cam_anchors.front_left.z_unit);
             
        z_unit_in_cube_dist = z_unit_of_cube_line_left_board + relative_middle_y_grid*(z_unit_of_cube_line_right_board - z_unit_of_cube_line_left_board);

        y_bot_lim = cube_base_y_pix - min_grid_z*z_unit_in_cube_dist;
        y_top_lim = cube_base_y_pix - max_grid_z*z_unit_in_cube_dist;

    elseif cam_side == "right"

        relative_x_grid = (cube_grid_x_right - cam_anchors.back_left.grid_x) / (cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);

        relative_top_y_grid = (cube_grid_y_top - cam_anchors.back_left.grid_y)/(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
        relative_bottom_y_grid = (cube_grid_y_bottom - cam_anchors.back_left.grid_y)/(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);

        % Calculate x of cube
        x_of_cube_line_left_board = cam_anchors.front_left.x + relative_x_grid*(cam_anchors.front_right.x - cam_anchors.front_left.x);
        x_of_cube_line_right_board = cam_anchors.back_left.x + relative_x_grid*(cam_anchors.back_right.x - cam_anchors.back_left.x);

        cube_top_x_pix = x_of_cube_line_right_board + relative_top_y_grid*(x_of_cube_line_left_board - x_of_cube_line_right_board);
        cube_bottom_x_pix = x_of_cube_line_right_board + relative_bottom_y_grid*(x_of_cube_line_left_board - x_of_cube_line_right_board);
        
        x_left_lim = cube_bottom_x_pix;
        x_right_lim = cube_top_x_pix;

        % Calculate z-unit mask
        y_of_cube_line_left_board = cam_anchors.front_left.y + relative_x_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);
        y_of_cube_line_right_board = cam_anchors.back_left.y + relative_x_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);

        relative_middle_y_grid = (relative_top_y_grid + relative_bottom_y_grid)/2;
        cube_base_y_pix = y_of_cube_line_right_board + relative_middle_y_grid*(y_of_cube_line_left_board - y_of_cube_line_right_board);

        % Calculate z-unit in cube pos
        z_unit_of_cube_line_left_board = cam_anchors.front_left.z_unit + relative_x_grid*(cam_anchors.front_right.z_unit - cam_anchors.front_left.z_unit);
        z_unit_of_cube_line_right_board = cam_anchors.back_left.z_unit + relative_x_grid*(cam_anchors.back_right.z_unit - cam_anchors.back_left.z_unit);
             
        z_unit_in_cube_dist = z_unit_of_cube_line_right_board + relative_middle_y_grid*(z_unit_of_cube_line_left_board - z_unit_of_cube_line_right_board);

        y_bot_lim = cube_base_y_pix - min_grid_z*z_unit_in_cube_dist;
        y_top_lim = cube_base_y_pix - max_grid_z*z_unit_in_cube_dist;

    elseif cam_side == "back"
        
        relative_y_grid = (cube_grid_y_top - cam_anchors.back_left.grid_y) / (cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);

        relative_left_x_grid = (cube_grid_x_left - cam_anchors.back_left.grid_x)/(cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
        relative_right_x_grid = (cube_grid_x_right - cam_anchors.back_left.grid_x)/(cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);

        % Calculate x of cube
        x_of_cube_line_left_board = cam_anchors.back_right.x + relative_y_grid*(cam_anchors.front_right.x - cam_anchors.back_right.x);
        x_of_cube_line_right_board = cam_anchors.back_left.x + relative_y_grid*(cam_anchors.front_left.x - cam_anchors.back_left.x);

        cube_left_x_pix = x_of_cube_line_right_board + relative_left_x_grid*(x_of_cube_line_left_board - x_of_cube_line_right_board);
        cube_right_x_pix = x_of_cube_line_right_board + relative_right_x_grid*(x_of_cube_line_left_board - x_of_cube_line_right_board);
        
        x_left_lim = cube_right_x_pix;
        x_right_lim = cube_left_x_pix;

        % Calculate z-unit mask
        y_of_cube_line_left_board = cam_anchors.back_right.y + relative_y_grid*(cam_anchors.front_right.y - cam_anchors.back_right.y);
        y_of_cube_line_right_board = cam_anchors.back_left.y + relative_y_grid*(cam_anchors.front_left.y - cam_anchors.back_left.y);

        relative_middle_x_grid = (relative_left_x_grid + relative_right_x_grid)/2;
        cube_base_y_pix = y_of_cube_line_right_board + relative_middle_x_grid*(y_of_cube_line_left_board - y_of_cube_line_right_board);

        % Calculate z-unit in cube pos
        z_unit_of_cube_line_left_board = cam_anchors.back_right.z_unit + relative_y_grid*(cam_anchors.front_right.z_unit - cam_anchors.back_right.z_unit);
        z_unit_of_cube_line_right_board = cam_anchors.back_left.z_unit + relative_y_grid*(cam_anchors.front_left.z_unit - cam_anchors.back_left.z_unit);

        z_unit_in_cube_dist = z_unit_of_cube_line_right_board + relative_middle_x_grid*(z_unit_of_cube_line_left_board - z_unit_of_cube_line_right_board);

        y_bot_lim = cube_base_y_pix - min_grid_z*z_unit_in_cube_dist;
        y_top_lim = cube_base_y_pix - max_grid_z*z_unit_in_cube_dist;

    end

    % Create the binary map

    % Add paddings
    x_padding = 0;
    y_padding = 0;
    x_left_lim = x_left_lim - x_padding;
    x_right_lim = x_right_lim + x_padding;
    y_top_lim = y_top_lim - y_padding;
    y_bot_lim = y_bot_lim + y_padding;


    % Clamp
    x_left_lim = max(min(x_left_lim,cam_width),1);
    x_right_lim = max(min(x_right_lim,cam_width),1);
    y_top_lim = max(min(y_top_lim,cam_height),1);
    y_bot_lim = max(min(y_bot_lim,cam_height),1);
    

    coord_binary_map = zeros(cam_height,cam_width);
    coord_binary_map(y_top_lim:y_bot_lim,x_left_lim:x_right_lim) = 1;

    
end

%% Functions - colors

function color = get_color_of_cube(img, x_cube, y_cube, width_cube, height_cube)

    % The function gets an image and the cube boundary box
    % The function returns the color name of the cube: "red", "yellow", "white" and "blue". 
    
    % Reference array of vectors (contain 6 vectors in the following
    % order - red_vec, yellow_vec, white_vec, blue_vec, black_vec, ground_vec), size 6*3.
    % for each of top,left,right,back cameras
    ref_array_struct = load("color_calib.mat");

    % Set an array to hold the sample points from the cube 
    sample_point_array = zeros([5 3]);
    
    % Set parameters
    sampel_factor = 4;
    top_img_grid_resolution = 20;
    
    % Set the x, y, width and height of the cube to be fixed to the image pixels
    y_cube = y_cube*top_img_grid_resolution;
    x_cube = x_cube*top_img_grid_resolution;
    height_cube = height_cube*top_img_grid_resolution;
    width_cube = width_cube*top_img_grid_resolution;
    
    % Sample the relevant points
    sample_point_array(1,:) = img(y_cube + round(height_cube/sampel_factor), x_cube + round(width_cube/sampel_factor), :); % sample at ((y+height)/4 , (x+width)/4)
    sample_point_array(2,:) = img(y_cube + round(height_cube/sampel_factor), x_cube + round((width_cube*(sampel_factor-1))/sampel_factor), :); % sample at ((y+height)/4 , 3*(x+width)/4)
    sample_point_array(3,:) = img(y_cube + round((height_cube*(sampel_factor-1))/sampel_factor), x_cube + round(width_cube/sampel_factor), :); % sample at (3*(y+height)/4 , (x+width)/4)
    sample_point_array(4,:) = img(y_cube + round((height_cube*(sampel_factor-1))/sampel_factor), x_cube + round((width_cube*(sampel_factor-1))/sampel_factor), :); % sample at (3*(y+height)/4 , 3*(x+width)/4)
    sample_point_array(5,:) = img(y_cube + round((height_cube*(sampel_factor/2))/sampel_factor), x_cube + round((width_cube*(sampel_factor/2))/sampel_factor), :); % sample at (2*(y+height)/4 , 2*(x+width)/4)
    
    % Calc the euclidean distance of the sample points from the ref vectors
    close_vec = zeros([1 5]);
    for i=1:5   % Pass on all the sample points
        [~, index] = min(sqrt(sum((( ref_array_struct.top_ref_array - sample_point_array(i,:) ).^2 ) .')));
        close_vec(i) = index;
    end
    
    % Select the most common index
    select_color = mode(close_vec);
    
    % Select the color of the cube
    color = ref_array_struct.colors_array(select_color);

    %{
    if select_color == 1
        color = "red";
    elseif select_color == 2
        color = "yellow";
    elseif select_color == 3
        color = "white";
    else
        color = "blue";
    end
    %}
    
end

function color_binary_map = get_color_filtered_binary_map(org_img, color_name, cam_side)
    % The function gets an image, a color name and a camera name
    % The function returns a binary map of pixels in range of the input color 
    
    % Parameters
    cnl_tresh = 0.2;

    % Reference array of vectors (contain 6 vectors in the following
    % order - red_vec, yellow_vec, white_vec, blue_vec, black_vec, ground_vec), size 6*3.
    % for each of top,left,right,back cameras
    ref_array_struct = load("color_calib.mat");

    % Select the relevant array by the camera
    switch cam_side
        case "top"
            ref_array = ref_array_struct.top_ref_array;
        case "left"
            ref_array = ref_array_struct.left_ref_array;
        case "right"
            ref_array = ref_array_struct.right_ref_array;
        case "back"
            ref_array = ref_array_struct.back_ref_array;
    end

    % Select the relevant color index
    color_num = find(ref_array_struct.colors_array == color_name);

    % Selecet the relevant RGB vector
    color_rgb_vec = ref_array(color_num,:);

    r_ref = color_rgb_vec(1);
    g_ref = color_rgb_vec(2);
    b_ref = color_rgb_vec(3);

    % select channels
    r_img = org_img(:,:,1);
    g_img = org_img(:,:,2);
    b_img = org_img(:,:,3);

    % Prepare binary maps by channel
    r_binary_map = (r_img > r_ref - cnl_tresh) & (r_img < r_ref + cnl_tresh);
    g_binary_map = (g_img > g_ref - cnl_tresh) & (g_img < g_ref + cnl_tresh);
    b_binary_map = (b_img > b_ref - cnl_tresh) & (b_img < b_ref + cnl_tresh);


    color_binary_map = r_binary_map .* g_binary_map .* b_binary_map;

end

function color_binary_map = get_color_filtered_binary_map_hsv(org_img, color_name, cam_side)
    % The function gets an image, a color name and a camera name
    % The function returns a binary map of pixels in range of the input color 
    
    % Parameters
    h_tresh = 0.2;
    s_tresh = 0.2;
    v_tresh = 0.2;

    % Reference array of vectors (contain 6 vectors in the following
    % order - red_vec, yellow_vec, white_vec, blue_vec, black_vec, ground_vec), size 6*3.
    % for each of top,left,right,back cameras
    ref_array_struct = load("color_calib.mat");

    % Select the relevant array by the camera
    switch cam_side
        case "top"
            ref_array = ref_array_struct.top_ref_array;
        case "left"
            ref_array = ref_array_struct.left_ref_array;
        case "right"
            ref_array = ref_array_struct.right_ref_array;
        case "back"
            ref_array = ref_array_struct.back_ref_array;
    end

    % Select the relevant color index
    color_num = find(ref_array_struct.colors_array == color_name);

    % Selecet the relevant RGB vector
    color_rgb_vec = ref_array(color_num,:);

    % convert the rgb to hsv
    color_hsv_vec = rgb2hsv(color_rgb_vec);
    h_ref = color_hsv_vec(1);
    s_ref = color_hsv_vec(2);
    v_ref = color_hsv_vec(3);

    % convert the input image to hsv
    img_hsv = rgb2hsv(org_img);
    h_img = img_hsv(:,:,1);
    s_img = img_hsv(:,:,2);
    v_img = img_hsv(:,:,3);

    % Prepare binary maps by channel
    h_binary_map = (h_img > h_ref - h_tresh) & (h_img < h_ref + h_tresh);
    s_binary_map = (s_img > s_ref - s_tresh) & (s_img < s_ref + s_tresh);
    v_binary_map = (v_img > v_ref - v_tresh) & (v_img < v_ref + v_tresh);

    disp("color = "+color_name+", side = "+cam_side+", HSV = ["+num2str(h_ref)+","+num2str(s_ref)+","+num2str(v_ref)+"]"+", RGB = ["+num2str(color_rgb_vec(1))+","+num2str(color_rgb_vec(2))+","+num2str(color_rgb_vec(3))+"]");

    %high_s_binary_map = (s_img > 0.7);
    %high_v_binary_map = (v_img > 0.7);

    % Create the final binary map

    % For black and white colors, don't filter by H value
    if color_name == "black" || color_name == "white"
        %color_binary_map = s_binary_map .* v_binary_map;
        color_binary_map = s_binary_map .* v_binary_map;
    else
        %color_binary_map = h_binary_map .* s_binary_map .* v_binary_map;
        color_binary_map = h_binary_map .* s_binary_map .* v_binary_map;
    end
end

function color_binary_map = get_color_filtered_binary_map_old(org_img, color_name, cam_side)
    % The function gets an image, a color name and a camera name
    % The function returns a binary map of pixels in range of the input color 
    
    %{
    % Parameters
    h_tresh = 0.3;
    s_tresh = 0.3;
    v_tresh = 0.3;

    % Reference array of vectors (contain 6 vectors in the following
    % order - red_vec, yellow_vec, white_vec, blue_vec, black_vec, ground_vec), size 6*3.
    % for each of top,left,right,back cameras
    ref_array_struct = load("color_calib.mat");

    % Select the relevant array by the camera
    switch cam_side
        case "top"
            ref_array = ref_array_struct.top_ref_array;
        case "left"
            ref_array = ref_array_struct.left_ref_array;
        case "right"
            ref_array = ref_array_struct.right_ref_array;
        case "back"
            ref_array = ref_array_struct.back_ref_array;
    end

    % Select the relevant color index
    color_num = color_str_to_color_num(color_name);

    % Selecet the relevant RGB vector
    color_rgb_vec = ref_array(color_num,:);

    % convert the rgb to hsv
    color_hsv_vec = rgb2hsv(color_rgb_vec);
    h_ref = color_hsv_vec(1);
    s_ref = color_hsv_vec(2);
    v_ref = color_hsv_vec(3);
    %disp(cam_side+" , "+color_name+" : "+"h_ref = "+num2str(h_ref)+", s_ref = "+num2str(s_ref)+", v_ref = "+num2str(v_ref));

    

    % Prepare binary maps by channel
    h_binary_map = (h_img > h_ref - h_tresh) & (h_img < h_ref + h_tresh);
    s_binary_map = (s_img > s_ref - s_tresh) & (s_img < s_ref + s_tresh);
    v_binary_map = (v_img > v_ref - v_tresh) & (v_img < v_ref + v_tresh);

    %}

    % convert the input image to hsv
    img_hsv = rgb2hsv(org_img);
    %h_img = img_hsv(:,:,1);
    s_img = img_hsv(:,:,2);
    v_img = img_hsv(:,:,3);

    high_s_binary_map = (s_img > 0.85);
    high_v_binary_map = (v_img > 0.85);

    % Create the final binary map

    % For black and white colors, don't filter by H value
    if color_name == "black" || color_name == "white"
        %color_binary_map = s_binary_map .* v_binary_map;
        color_binary_map = high_v_binary_map;
    else
        %color_binary_map = h_binary_map .* s_binary_map .* v_binary_map;
        color_binary_map = high_s_binary_map;
    end
end

%% Functions - Detect from sides

function [detected_new_cube, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height, predicted_color_name] = get_lego_grid_xy_from_sides_cameras(cur_left,prev_left,cur_right,prev_right,cur_back,prev_back,lego_grid_x,left_cam_anchors,right_cam_anchors,back_cam_anchors,left_binary_mask,right_binary_mask,back_binary_mask,debug_plot_binary_map)
    % The function estimates the x,y coordinates of a cube based on the
    % sides cameras only
    % The function gets cur and prev from 3 side cameras, calibration
    % anchors and binary masks for side camers
    % The function returns the [lego_grid_x, lego_grid_y, lego_grid_width,
    % lego_grid_height] parameters of the new cube, and a detected_new_cube
    % flag indicating if a cube detected

    lego_grid_x = 0;
    lego_grid_y = 0;
    lego_grid_width = 0;
    lego_grid_height = 0;
    predicted_color_name = "Empty";

    %{
    % Prev - not tight binary maps
    highest_z_in_game = get_highest_occupied_z_in_game_board();
    left_cam_min_max_z_binary_map = get_min_max_z_binary_map(0,highest_z_in_game+1,"left",left_cam_anchors);
    right_cam_min_max_z_binary_map = get_min_max_z_binary_map(0,highest_z_in_game+1,"right",right_cam_anchors);
    back_cam_min_max_z_binary_map = get_min_max_z_binary_map(0,highest_z_in_game+1,"back",back_cam_anchors);
    %}

    left_cam_min_max_z_binary_map = get_tight_min_max_z_binary_map("left",left_cam_anchors);
    right_cam_min_max_z_binary_map = get_tight_min_max_z_binary_map("right",right_cam_anchors);
    back_cam_min_max_z_binary_map = get_tight_min_max_z_binary_map("back",back_cam_anchors);

    optional_expected_colors = ["red","blue","yellow","white"];
    amount_of_colors = length(optional_expected_colors);

    found_match_from_two_sweeps_arr = zeros(1,amount_of_colors);
    match_from_two_sweeps_score_arr = zeros(1,amount_of_colors);
    lego_grid_x_arr = zeros(1,amount_of_colors);
    lego_grid_y_arr = zeros(1,amount_of_colors);
    lego_grid_width_arr = zeros(1,amount_of_colors);
    lego_grid_height_arr = zeros(1,amount_of_colors);


    for col_idx = 1:amount_of_colors

        % Check for loop color
        loop_color_name = optional_expected_colors(col_idx);
        %disp("Loop color = "+loop_color_name);

        % Calculate parameters sweep for all 3 cameras
        [detected_new_cube_left, detection_score_left, coordinates_sweep_left] = get_coordinates_sweep_from_side_camera(prev_left, cur_left, "left", left_cam_anchors, left_binary_mask,left_cam_min_max_z_binary_map, loop_color_name,debug_plot_binary_map);
        [detected_new_cube_right, detection_score_right, coordinates_sweep_right] = get_coordinates_sweep_from_side_camera(prev_right, cur_right, "right", right_cam_anchors, right_binary_mask,right_cam_min_max_z_binary_map, loop_color_name,debug_plot_binary_map);
        [detected_new_cube_back, ~ ,coordinates_sweep_back] = get_coordinates_sweep_from_side_camera(prev_back, cur_back, "back", back_cam_anchors, back_binary_mask,back_cam_min_max_z_binary_map, loop_color_name,debug_plot_binary_map);
    
        % Select a pair of {right/left}+{back} camera to calculate x,y from
        if detected_new_cube_back && (detected_new_cube_left || detected_new_cube_right)
            pair_sidecams_detected_new_cube = true;
            if detected_new_cube_left && detected_new_cube_right
                if detection_score_left > detection_score_right
                    [found_match_from_two_sweeps_arr(col_idx),match_from_two_sweeps_score_arr(col_idx), lego_grid_x_arr(col_idx), lego_grid_y_arr(col_idx), lego_grid_width_arr(col_idx), lego_grid_height_arr(col_idx)] = calculate_xy_from_side_and_back_parameters_sweep(coordinates_sweep_left, coordinates_sweep_back);
                else
                     [found_match_from_two_sweeps_arr(col_idx),match_from_two_sweeps_score_arr(col_idx), lego_grid_x_arr(col_idx), lego_grid_y_arr(col_idx), lego_grid_width_arr(col_idx), lego_grid_height_arr(col_idx)] = calculate_xy_from_side_and_back_parameters_sweep(coordinates_sweep_right, coordinates_sweep_back);
                end

            elseif detected_new_cube_left && ~detected_new_cube_right
                %disp("left + back");
                
                [found_match_from_two_sweeps_arr(col_idx),match_from_two_sweeps_score_arr(col_idx), lego_grid_x_arr(col_idx), lego_grid_y_arr(col_idx), lego_grid_width_arr(col_idx), lego_grid_height_arr(col_idx)] = calculate_xy_from_side_and_back_parameters_sweep(coordinates_sweep_left, coordinates_sweep_back);
            else
                %disp("right + back");
                [found_match_from_two_sweeps_arr(col_idx),match_from_two_sweeps_score_arr(col_idx), lego_grid_x_arr(col_idx), lego_grid_y_arr(col_idx), lego_grid_width_arr(col_idx), lego_grid_height_arr(col_idx)] = calculate_xy_from_side_and_back_parameters_sweep(coordinates_sweep_right, coordinates_sweep_back);
            end
        else
            % Not a valid combination of detected cameras
            pair_sidecams_detected_new_cube = false;
            found_match_from_two_sweeps_arr(col_idx) = false;
        end
    
        %{
        disp("for color: "+loop_color_name);
        if pair_sidecams_detected_new_cube
            if found_match_from_two_sweeps_arr(col_idx)
                disp("XY predicted");
            else
                disp("found 2 cameras, sweep not matched");
            end
        else
           disp("didn't find 2 cameras (back + side)");
        end
        %}

        %{
        if pair_sidecams_detected_new_cube && found_match_from_two_sweeps_arr(col_idx)
            disp("coordinates sweeps for color : "+loop_color_name);
            coordinates_sweeps = zeros(24,4,3);
            coordinates_sweeps(:,:,1) = coordinates_sweep_left(:,:);
            coordinates_sweeps(:,:,2) = coordinates_sweep_right(:,:);
            coordinates_sweeps(:,:,3) = coordinates_sweep_back(:,:);
            camera_names = ["left","right","back"];
            for c = 1:3
                loop_coordinates_sweep(:,:) = coordinates_sweeps(:,:,c);
                loop_camera_name = camera_names(c);
                disp("camera: "+loop_camera_name);
                if c <= 2
                    disp("x         y           height      z-height-above-floor        z-height self");
                else
                    disp("y         x           width       z-height-above-floor        z-height self");
                end
        
                for i = 1:24
                    disp(num2str(i-1)+"       "+num2str(loop_coordinates_sweep(i,1))+"       "+num2str(loop_coordinates_sweep(i,2))+"       "+num2str(loop_coordinates_sweep(i,3))+"                "+num2str(loop_coordinates_sweep(i,4)));
                end
            end
        end
        %}
    end

    
    disp("final result from side x-y");
    disp(optional_expected_colors);
    disp(found_match_from_two_sweeps_arr);
    disp(match_from_two_sweeps_score_arr);
    disp(lego_grid_x_arr);
    disp(lego_grid_y_arr);
    disp(lego_grid_width_arr);
    disp(lego_grid_height_arr);

    % Select result
    if sum(found_match_from_two_sweeps_arr(:))==0
        detected_new_cube = false;
        disp("Could'nt define selected color in xy prediction");
        
    elseif sum(found_match_from_two_sweeps_arr(:))==1
        detected_new_cube = true;
        disp("Winner color selected");
        [~,sel_col_idx] = max(found_match_from_two_sweeps_arr);
        lego_grid_x = lego_grid_x_arr(sel_col_idx);
        lego_grid_y = lego_grid_y_arr(sel_col_idx);
        lego_grid_width = lego_grid_width_arr(sel_col_idx);
        lego_grid_height = lego_grid_height_arr(sel_col_idx);
        predicted_color_name = optional_expected_colors(sel_col_idx);
    else % More than one match
        detected_new_cube = false;
        disp("Two of more xy prediction from side cameras");
    end


    
end

function [detected_new_cube, detection_score, coordinates_sweep] = get_coordinates_sweep_from_side_camera(prev_img, cur_img, cam_side, cam_anchors, cam_binary_mask, coord_based_binary_map, expected_color,debug_plot_binary_map)
    
    % The function gets:
    %   prev,cur images from side camera
    %   cam_side - the camera name "left"/"right"/"back"
    %   calibration anchors and binary masks for the relevant camera

    % The function returns "coordinates_sweep" for the camera:
    %   For a search coordinate (x for left and right cameras, y for back
    %   camera) runs from 0 to grid_size-1, if the cube is located in this search coordinate:
    %       col no. 1 - The estimated other x/y coordinate
    %       col no. 2 - The estimated width/height (height for left and
    %       right cameras, width for back camera)
    %       col no. 3 - The estimated z-unit height coordinate
    %       col no. 4 - height of cube in z-units

    % The function returns also a flag to indicate of found a cube
    % and a score for the detection (the detected area)

    global grid_size

    % Init return values
    detected_new_cube = false;
    detection_score = 0;
    coordinates_sweep = 0;

    area_lower_treshold_to_detect_cube = 300;
    area_upper_treshold_to_detect_cube = 8000;


    % Generate binary image
    color_binary_mask = get_color_filtered_binary_map(cur_img,expected_color,cam_side);
    final_binary_map = cam_binary_mask .* color_binary_mask .* coord_based_binary_map;
    binary_map = images_diff_binary_map(prev_img, cur_img, final_binary_map,true);


    if debug_plot_binary_map
        figure;
        subplot(2,3,1);
        imshow(binary_map);
        title("cam: "+cam_side+" , color: "+expected_color);
        subplot(2,3,2);
        imshow(final_binary_map);
        title("final mask");
        subplot(2,3,3);
        imshow(prev_img);
        subplot(2,3,4);
        imshow(cur_img);
        subplot(2,3,5);
        imshow(color_binary_mask);
        title("color binary mask");
        subplot(2,3,6);
        imshow(coord_based_binary_map);
        title("coord binary mask");
    end


    % Get properties of boundry box to detect the y and height
    % find center of mass in the binary image
    stats = regionprops(binary_map, 'BoundingBox', 'Centroid','Area');
    binary_map_total_area = sum(binary_map(:));

    % Check if detected area is above treshold
    if ~isempty(stats)
    
        %if stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube
        if stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube
            cube_left_edge = stats.BoundingBox(1);
            cube_right_edge = stats.BoundingBox(1) + stats.BoundingBox(3);
            cube_top_edge = stats.BoundingBox(2);
            cube_bottom_edge = stats.BoundingBox(2) + stats.BoundingBox(4);
    
            detected_new_cube = true;
            detection_score = stats.Area;
            coordinates_sweep = zeros(24,4);
    
            if cam_side == "left"
    
                %disp("cube_top_edge = "+cube_top_edge);
                %disp("cube_bottom_edge = "+cube_bottom_edge);
    
                for loop_x = 0:23
                    relative_x_grid = (loop_x - cam_anchors.back_left.grid_x) / (cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
    
                    % Calculate x of cube
                    x_of_cube_line_left_board = cam_anchors.back_left.x + relative_x_grid*(cam_anchors.back_right.x - cam_anchors.back_left.x);
                    x_of_cube_line_right_board = cam_anchors.front_left.x + relative_x_grid*(cam_anchors.front_right.x - cam_anchors.front_left.x);
    
                    relative_y_cube_left_edge = (cube_left_edge - x_of_cube_line_left_board)/(x_of_cube_line_right_board - x_of_cube_line_left_board);
                    relative_y_cube_right_edge = (cube_right_edge - x_of_cube_line_left_board)/(x_of_cube_line_right_board - x_of_cube_line_left_board);
    
                    cube_top_grid_y = cam_anchors.back_left.grid_y + relative_y_cube_left_edge*(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
                    cube_bottom_grid_y = cam_anchors.back_left.grid_y + relative_y_cube_right_edge*(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
                    cube_height = cube_bottom_grid_y - cube_top_grid_y;
    
                    % Calculate z-unit in cube pos
                    z_unit_of_cube_line_left_board = cam_anchors.back_left.z_unit + relative_x_grid*(cam_anchors.back_right.z_unit - cam_anchors.back_left.z_unit);
                    z_unit_of_cube_line_right_board = cam_anchors.front_left.z_unit + relative_x_grid*(cam_anchors.front_right.z_unit - cam_anchors.front_left.z_unit);
            
                    cube_middle_grid_y = (cube_top_grid_y + cube_bottom_grid_y)/2;
                    relative_cube_grid_y = cube_middle_grid_y/grid_size;
                    z_unit_in_cube_dist = z_unit_of_cube_line_left_board + relative_cube_grid_y*(z_unit_of_cube_line_right_board - z_unit_of_cube_line_left_board);
    
                    % Calculate y of cube
                    y_of_cube_line_left_board = cam_anchors.back_left.y + relative_x_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);
                    y_of_cube_line_right_board = cam_anchors.front_left.y + relative_x_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);
                    y_of_base_height = y_of_cube_line_left_board + relative_cube_grid_y*(y_of_cube_line_right_board - y_of_cube_line_left_board);
    
                    % Estimate height
                    estimated_z = (y_of_base_height - cube_bottom_edge)/z_unit_in_cube_dist;
                    height_of_cubes_in_z_units = (cube_bottom_edge - cube_top_edge)/z_unit_in_cube_dist;
    
                    % Fill result in coordinates_sweep matrix
                    coordinates_sweep(loop_x+1,1) = cube_top_grid_y;
                    coordinates_sweep(loop_x+1,2) = cube_height;
                    coordinates_sweep(loop_x+1,3) = estimated_z; 
                    coordinates_sweep(loop_x+1,4) = height_of_cubes_in_z_units; 
    
                end
    
            elseif cam_side == "right"
                for loop_x = 0:23
                    relative_x_grid = (loop_x - cam_anchors.back_left.grid_x) / (cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
                    
                    % Calculate x of cube
                    x_of_cube_line_left_board = cam_anchors.front_left.x + relative_x_grid*(cam_anchors.front_right.x - cam_anchors.front_left.x);
                    x_of_cube_line_right_board = cam_anchors.back_left.x + relative_x_grid*(cam_anchors.back_right.x - cam_anchors.back_left.x);
    
                    relative_y_cube_left_board = (cube_left_edge - x_of_cube_line_right_board)/(x_of_cube_line_left_board - x_of_cube_line_right_board);
                    relative_y_cube_right_board = (cube_right_edge - x_of_cube_line_right_board)/(x_of_cube_line_left_board - x_of_cube_line_right_board);
    
                    cube_top_grid_y = cam_anchors.back_left.grid_y + relative_y_cube_right_board*(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
                    cube_bottom_grid_y = cam_anchors.back_left.grid_y + relative_y_cube_left_board*(cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
                    cube_height = cube_bottom_grid_y - cube_top_grid_y;
    
                    
                       
                    % Calculate z-unit in cube pos
                    z_unit_of_cube_line_left_board = cam_anchors.front_left.z_unit + relative_x_grid*(cam_anchors.front_right.z_unit - cam_anchors.front_left.z_unit);
                    z_unit_of_cube_line_right_board = cam_anchors.back_left.z_unit + relative_x_grid*(cam_anchors.back_right.z_unit - cam_anchors.back_left.z_unit);
            
                    cube_middle_grid_y = (cube_top_grid_y + cube_bottom_grid_y)/2;
                    relative_cube_grid_y = cube_middle_grid_y/grid_size;
                    z_unit_in_cube_dist = z_unit_of_cube_line_right_board + relative_cube_grid_y*(z_unit_of_cube_line_left_board - z_unit_of_cube_line_right_board);
                    
                    % Calculate y of cube
                    y_of_cube_line_left_edge = cam_anchors.front_left.y + relative_x_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);
                    y_of_cube_line_right_edge = cam_anchors.back_left.y + relative_x_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);    
                    y_of_base_height = y_of_cube_line_right_edge + relative_cube_grid_y*(y_of_cube_line_left_edge - y_of_cube_line_right_edge);
    
                    % Estimate height
                    estimated_z = (y_of_base_height - cube_bottom_edge)/z_unit_in_cube_dist;
                    height_of_cubes_in_z_units = (cube_bottom_edge - cube_top_edge)/z_unit_in_cube_dist;
    
                    % Fill result in coordinates_sweep matrix
                    coordinates_sweep(loop_x+1,1) = cube_top_grid_y;
                    coordinates_sweep(loop_x+1,2) = cube_height;
                    coordinates_sweep(loop_x+1,3) = estimated_z; 
                    coordinates_sweep(loop_x+1,4) = height_of_cubes_in_z_units; 
    
                end
    
            elseif cam_side == "back"
                
                for loop_y = 0:23
    
                    relative_y_grid = (loop_y - cam_anchors.back_left.grid_y) / (cam_anchors.front_left.grid_y - cam_anchors.back_left.grid_y);
                    %disp("relative_y_grid = "+sum2str(relative_y_grid));
    
                    % Calculate x of cube
                    x_of_cube_line_left_board = cam_anchors.back_right.x + relative_y_grid*(cam_anchors.front_right.x - cam_anchors.back_right.x);
                    x_of_cube_line_right_board = cam_anchors.back_left.x + relative_y_grid*(cam_anchors.front_left.x - cam_anchors.back_left.x);
                    %disp("x_of_cube_line_left_board = "+sum2str(x_of_cube_line_left_board));
                    %disp("x_of_cube_line_right_board = "+sum2str(x_of_cube_line_right_board));
    
                    relative_x_cube_left_board = (cube_left_edge - x_of_cube_line_right_board)/(x_of_cube_line_left_board - x_of_cube_line_right_board);
                    relative_x_cube_right_board = (cube_right_edge - x_of_cube_line_right_board)/(x_of_cube_line_left_board - x_of_cube_line_right_board);
                    %disp("relative_x_cube_left_board = "+sum2str(relative_x_cube_left_board));
                    %disp("relative_x_cube_right_board = "+sum2str(relative_x_cube_right_board));
                    
                    cube_left_grid_x = cam_anchors.back_left.grid_x + relative_x_cube_right_board*(cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
                    cube_right_grid_x = cam_anchors.back_left.grid_x + relative_x_cube_left_board*(cam_anchors.back_right.grid_x - cam_anchors.back_left.grid_x);
                    cube_width = cube_right_grid_x - cube_left_grid_x;
                    %disp("cube_left_grid_x = "+sum2str(cube_left_grid_x));
                    %disp("cube_right_grid_x = "+sum2str(cube_right_grid_x));
                    %disp("cube_width = "+sum2str(cube_width));
      
                    % Calculate z-unit in cube pos
                    z_unit_of_cube_line_left_board = cam_anchors.back_right.z_unit + relative_y_grid*(cam_anchors.front_right.z_unit - cam_anchors.back_right.z_unit);
                    z_unit_of_cube_line_right_board = cam_anchors.back_left.z_unit + relative_y_grid*(cam_anchors.front_left.z_unit - cam_anchors.back_left.z_unit);
            
                    cube_middle_grid_x = (cube_left_grid_x + cube_right_grid_x)/2;
                    relative_cube_grid_x = cube_middle_grid_x/grid_size;
                    z_unit_in_cube_dist = z_unit_of_cube_line_right_board + relative_cube_grid_x*(z_unit_of_cube_line_left_board - z_unit_of_cube_line_right_board);
                    
                    % Calculate y of cube
                    y_of_cube_line_left_edge = cam_anchors.back_left.y + relative_y_grid*(cam_anchors.back_right.y - cam_anchors.back_left.y);
                    y_of_cube_line_right_edge = cam_anchors.front_left.y + relative_y_grid*(cam_anchors.front_right.y - cam_anchors.front_left.y);
                    y_of_base_height = y_of_cube_line_left_edge + relative_cube_grid_x*(y_of_cube_line_right_edge - y_of_cube_line_left_edge);
    
                    % Estimate height
                    estimated_z = (y_of_base_height - cube_bottom_edge)/z_unit_in_cube_dist;
                    height_of_cubes_in_z_units = (cube_bottom_edge - cube_top_edge)/z_unit_in_cube_dist;
    
                    % Fill result in coordinates_sweep matrix
                    coordinates_sweep(loop_y+1,1) = cube_left_grid_x;
                    coordinates_sweep(loop_y+1,2) = cube_width;
                    coordinates_sweep(loop_y+1,3) = estimated_z; 
                    coordinates_sweep(loop_y+1,4) = height_of_cubes_in_z_units; 
                end
            end
                %disp(cam_side+": Generated parameters sweep");
        else
            % Didn't detect cube from top camera
            detected_new_cube = false;
            detection_score = 0;
            coordinates_sweep = 0;
    
            %{
            if stats.Area < area_lower_treshold_to_detect_cube
                %disp(cam_side+": Side camera detect too SMALL area to be a cube");
            else
                %disp(cam_side+": Side camera detect too LARGE area to be a cube");
            end
            %}
    
        end
    end

end

function [match_found, match_score, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height] = calculate_xy_from_side_and_back_parameters_sweep(side_param_sweep, back_param_sweep)
    % The function gets parameters sweep (as defined in
    % 'get_coordinates_sweep_from_side_camera' function) and returns the
    % [lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height] of the
    % cube swing sweep-matching

    % The algorithm: 
    %   Iterate over all x in {0...23}
    %       check what y is related to this x
    %       y1 = floor(y), wy(y1) = y - y1
    %       y2 = ceil(y), wy(y2) = y2 - y
    %       for yi = y1,y2:
    %           check what xi is related to this yi
    %           xi1 = floor(xi), wx(xi1) = xi - xi1
    %           xi2 = ceil(xi), wx(xi2) = xi2 - xi
    %           for xij = xi1,xi2:
    %               if xij == x
    %                   w_total(xij) = wy(yi) + wx(xij)
    %               else
    %                   x_total(xij) = Inf
    %   the xij with the min w_total(xij) defines the couple (xij,yi) from
    %   all x = 0,...,23, i = 1,2 , j = 1,2


    w_total = zeros(1,24);
    matched_y = zeros(1,24);

    for x = 0:23
        
        %str = "x = "+num2str(x);
        yi_arr = zeros(1,2);
        wy_arr = zeros(1,2);
        w_total_x = zeros(1,4);

        y = side_param_sweep(x+1,1);
        yi_arr(1) = floor(y);
        wy_arr(1) = y - floor(y);
        yi_arr(2) = ceil(y);
        wy_arr(2) = ceil(y) - y;

        %str = str + ", y1 = "+num2str(yi_arr(1))+"{wy="+num2str(wy_arr(1))+"}";
        %str = str + ", y2 = "+num2str(yi_arr(2))+"{wy="+num2str(wy_arr(2))+"}";

        for i = 1:2
            yi = yi_arr(i);
            if yi >= 0 && yi <= 23
                xij = back_param_sweep(yi+1,1);
                xij_arr = zeros(1,2);
                wx_arr = zeros(1,2);
                xij_arr(1) = floor(xij);
                wx_arr(1) = xij - floor(xij);
                xij_arr(2) = ceil(xij);
                wx_arr(2) = ceil(xij) - xij;
                for j = 1:2
                    xij = xij_arr(j);
                    %str = str + ", x"+num2str(i)+num2str(j)+" = "+num2str(xij)+"{wx="+num2str(wx_arr(j))+"}";
                    if xij == x
                        w_total_x(2*(i-1) + (j-1) + 1) = wy_arr(i) + wx_arr(j);
                    else
                        w_total_x(2*(i-1) + (j-1) + 1) = inf;
                    end
                end
            else
                w_total_x(2*(i-1) + 1) = inf;
                w_total_x(2*(i-1) + 2) = inf;
            end
        end

        % Select the min w_total value
        [min_w_total_x,min_w_total_x_idx] = min(w_total_x);
        w_total(x+1) = min_w_total_x;
        if min_w_total_x_idx < 3
            matched_y(x+1) = yi_arr(1);
        else
            matched_y(x+1) = yi_arr(2);
        end  

        %str = str + ", min total: ["+num2str(w_total_x(1))+" , "+num2str(w_total_x(2))+" , "+num2str(w_total_x(3))+" , "++num2str(w_total_x(4))+" ]";
        %fprintf('%s',str);
        %disp("-----");
    end

    % Select the min w_total value
    [min_w_total,min_w_total_idx] = min(w_total);
    % The matched couple are [x = min_w_total_idx - 1, y = matched_y(min_w_total_idx)]
    if min_w_total < inf
        match_found = true;
        match_score = 1; % TODO - set relevant score (area of cubes...)
        lego_grid_x = min_w_total_idx - 1;
        lego_grid_y = matched_y(min_w_total_idx);
        estimated_lego_grid_width = back_param_sweep(min_w_total_idx,2);
        estimated_lego_grid_height = side_param_sweep(min_w_total_idx,2);
        if estimated_lego_grid_width < estimated_lego_grid_height
            lego_grid_width = 2;
            lego_grid_height = 4;
        else
            lego_grid_width = 4;
            lego_grid_height = 2;
        end
    else
        match_found = false;
        match_score = 0;
        lego_grid_x = 0;
        lego_grid_y = 0;
        lego_grid_width = 0;
        lego_grid_height = 0;
    end
end

function coord_binary_map = get_min_max_z_binary_map(min_grid_z,max_grid_z,cam_side,cam_anchors)
    global grid_size
    global cam_width cam_height
    accumulated_binary_maps = zeros(cam_height,cam_width);

    if cam_side == "back"
        for loop_y = 0:23
            accumulated_binary_maps = accumulated_binary_maps + get_coordinates_based_binary_map(0,grid_size,loop_y,loop_y+1,min_grid_z, max_grid_z, cam_side,cam_anchors);
        end
    else
        for loop_x = 0:23
            accumulated_binary_maps = accumulated_binary_maps + get_coordinates_based_binary_map(loop_x,loop_x+1,0,grid_size,min_grid_z, max_grid_z, cam_side,cam_anchors);
        end
    end

    coord_binary_map = (accumulated_binary_maps >= 1);
end

function coord_binary_map = get_tight_min_max_z_binary_map(cam_side,cam_anchors)
    global grid_size
    global cam_width cam_height
    accumulated_binary_maps = zeros(cam_height,cam_width);
    disp("coord binary map: "+cam_side);
    if cam_side == "back"
        
        for loop_x = 0:23
            min_x = max(loop_x-3,0);
            max_x = min(loop_x+3,grid_size-1);
            highest_z_in_loop_x_and_neighbors = get_highest_occupied_z_in_coordinates(min_x,0,max_x - min_x,grid_size);
            for loop_y = 0:23
                accumulated_binary_maps = accumulated_binary_maps + get_coordinates_based_binary_map(min_x,max_x,loop_y,loop_y+1,0, highest_z_in_loop_x_and_neighbors+2, cam_side,cam_anchors);
            end            
        end
    else
        for loop_y = 0:23
            min_y = max(loop_y-3,0);
            max_y = min(loop_y+3,grid_size-1);
            highest_z_in_loop_y_and_neighbors = get_highest_occupied_z_in_coordinates(0,min_y,grid_size,max_y-min_y);
            for loop_x = 0:23
                accumulated_binary_maps = accumulated_binary_maps + get_coordinates_based_binary_map(loop_x,loop_x+1,min_y,max_y,0, highest_z_in_loop_y_and_neighbors+2, cam_side,cam_anchors);
            end
        end
    end

    coord_binary_map = (accumulated_binary_maps >= 1);
end

%% Functions - detect half-covered cube

function [detected_partial_cube, lego_grid_x, lego_grid_y, lego_grid_width, lego_grid_height] = get_partial_cube_detection(cur_img,prev_img,cube_color)
    % The function gets an image and looking for partial-cube (a cube that is
    % half-overlapped with cube in the same color)
    
    global top_img_grid_resolution
    global cam_height

    % Init as didn't detect a partial-cube
    detected_partial_cube = false; 
    lego_grid_x = 0;
    lego_grid_y = 0;
    lego_grid_width = 0;
    lego_grid_height = 0;

    % The min area is 2X1 cube, which is ~40*20=800 pixels.
    % The max area is 2X3 cube, which is ~40*60=2400 pixels.
    % The treshold will be around it
    area_lower_treshold_to_detect_cube = 500;
    area_upper_treshold_to_detect_cube = 2700;
    
    optional_colors = ["red","blue","yellow","white","ground_color"];
    amount_of_colors = length(optional_colors);
    binary_map_area_result_arr = zeros(1,amount_of_colors);

    % calc the binary map of the new cube for each color
    for loop_color_idx = 1:amount_of_colors
        loop_color_name = optional_colors(loop_color_idx);
        color_binary_map = get_color_filtered_binary_map(cur_img,loop_color_name,"top");
        binary_map = images_diff_binary_map(prev_img, cur_img,color_binary_map,true);

        stats = regionprops(binary_map, 'BoundingBox', 'Centroid', 'Area');
        if ~isempty(stats) && stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube
            binary_map_area_result_arr(loop_color_idx) = stats.Area;
        end
    end

    % Select the color with the highest area
    [~,selected_color_index] = max(binary_map_area_result_arr);
    cube_color = optional_colors(selected_color_index);
    %disp("selected color = "+cube_color);

    color_binary_map = get_color_filtered_binary_map(cur_img,cube_color,"top");
    binary_map = images_diff_binary_map(prev_img, cur_img,color_binary_map,true);
    
    % Calc automaticlly the center of mass and the bounding box
    stats = regionprops(binary_map, 'BoundingBox', 'Centroid', 'Area');
    
    % Check if detected area is above treshold
    if ~isempty(stats) && stats.Area > area_lower_treshold_to_detect_cube && stats.Area < area_upper_treshold_to_detect_cube


        %--------------------------- Center -----------------------------------    
        % Center of mass (automaticlly computation)
        x_center_auto = round(stats.Centroid(1));
        y_center_auto = round(stats.Centroid(2));

        % Set a 1D array to save the amount of ones in each row in the 2D board
        ones_for_each_row = sum(binary_map, 2); % size = row_num*1

        % Set a 1D array to save the amount of ones in each column in the 2D board
        ones_for_each_col = sum(binary_map, 1); % size = col_num*1

        % diff vector for the rows
        diff_row = ones_for_each_row(2:end) - ones_for_each_row(1:end-1);

        % diff vector for the col
        diff_col = ones_for_each_col(2:end) - ones_for_each_col(1:end-1);

        % find the 2 places in the row vector with the maximum
        % values (the places with maximum change) from left and rigth to the
        % center of mass    
        [max_value_row, max_index_row] = max(diff_row(1:y_center_auto));
        [min_value_row, min_index_row] = min(diff_row(y_center_auto+1:end));
        min_index_row = min_index_row + y_center_auto;
        % find the 2 places in the col vector with the maximum abs value
        [max_value_col, max_index_col] = max(diff_col(1:x_center_auto));
        [min_value_col, min_index_col] = min(diff_col(x_center_auto+1:end));
        min_index_col = min_index_col + x_center_auto;

        % Hanlde pixels on edges
        if ones_for_each_row(1) > abs(max_value_row)
            max_value_row = ones_for_each_row(1);
            max_index_row = 1;
        end
        if ones_for_each_row(cam_height) > abs(min_value_row)
            min_value_row = ones_for_each_row(cam_height);
            min_index_row = cam_height;
        end
        if ones_for_each_col(1) > abs(max_value_col)
            max_value_col = ones_for_each_col(1);
            max_index_col = 1;
        end
        if ones_for_each_col(cam_height) > abs(min_value_col)
            min_value_col = ones_for_each_col(cam_height);
            min_index_col = cam_height;
        end

        % ------ Check validity of the partial-cube ----------------------------------
            
        % Make sure that the area bounded in the [top:bottom,left:right] is
        % almost (90%) of the total area of detected pixels in the original
        % binary map
        detected_cube_mask = zeros(size(binary_map));
        detected_cube_mask(max_index_row:min_index_row,max_index_col:min_index_col) = 1;

        %disp(["bounds",max_index_row,":",min_index_row,",",max_index_col,":",min_index_col]);

        area_inside_detected_cube_binary_map = binary_map.*detected_cube_mask;
        stats_inside_detected_cube = regionprops(area_inside_detected_cube_binary_map, 'Area');
        %disp(["Validity area > 0.9",(stats_inside_detected_cube.Area / stats.Area)]);
        if stats_inside_detected_cube.Area / stats.Area > 0.9



            % Calculate the grid [x,y,w,h]
            lego_grid_top = round(abs(max_index_row)/top_img_grid_resolution);
            lego_grid_bottom = round(abs(min_index_row)/top_img_grid_resolution);
            lego_grid_left = round(abs(max_index_col)/top_img_grid_resolution);
            lego_grid_right = round(abs(min_index_col)/top_img_grid_resolution);

            lego_grid_x = lego_grid_left;
            lego_grid_y = lego_grid_top;
            lego_grid_width = lego_grid_right - lego_grid_left;
            lego_grid_height = lego_grid_bottom - lego_grid_top;

            %disp("Partial cube detected");
            %disp(["Partial cube detected","x",lego_grid_x,"y",lego_grid_y,"width",lego_grid_width,"height",lego_grid_height])

            detected_partial_cube = true;

        end
    end       
end

%% Geometrical transformation

function img_tforms = load_geometrical_transformation()
    img_tforms = load('img_tfrom.mat');
end

function [left_cam_anchors,right_cam_anchors,back_cam_anchors] = load_side_images_corners_coordinates()

    img_sides_corners = load('img_sides_corners.mat');

    % Measure the x,y, z-unit height in pixels, x_grid and y_grid for each of the sides cameras

    % ----- Left camera ------

    left_cam_anchors.back_left.x = img_sides_corners.corns_cam_left_x(7);
    left_cam_anchors.back_right.x = img_sides_corners.corns_cam_left_x(1);
    left_cam_anchors.front_left.x = img_sides_corners.corns_cam_left_x(5);
    left_cam_anchors.front_right.x = img_sides_corners.corns_cam_left_x(3);

    left_cam_anchors.back_left.y = img_sides_corners.corns_cam_left_y(7);
    left_cam_anchors.back_right.y = img_sides_corners.corns_cam_left_y(1);
    left_cam_anchors.front_left.y = img_sides_corners.corns_cam_left_y(5);
    left_cam_anchors.front_right.y = img_sides_corners.corns_cam_left_y(3);

    left_cam_anchors.back_left.z_unit = img_sides_corners.corns_cam_left_y(7) - img_sides_corners.corns_cam_left_y(8);
    left_cam_anchors.back_right.z_unit = img_sides_corners.corns_cam_left_y(1) - img_sides_corners.corns_cam_left_y(2);
    left_cam_anchors.front_left.z_unit = img_sides_corners.corns_cam_left_y(5) - img_sides_corners.corns_cam_left_y(6);
    left_cam_anchors.front_right.z_unit = img_sides_corners.corns_cam_left_y(3) - img_sides_corners.corns_cam_left_y(4);

    left_cam_anchors.back_left.grid_x = 0;
    left_cam_anchors.back_right.grid_x = 20;
    left_cam_anchors.front_left.grid_x = 0;
    left_cam_anchors.front_right.grid_x = 20;

    left_cam_anchors.back_left.grid_y = 2;
    left_cam_anchors.back_right.grid_y = 2;
    left_cam_anchors.front_left.grid_y = 22;
    left_cam_anchors.front_right.grid_y = 22;

    % ----- Right camera ------

    right_cam_anchors.back_left.x = img_sides_corners.corns_cam_right_x(3);
    right_cam_anchors.back_right.x = img_sides_corners.corns_cam_right_x(5);
    right_cam_anchors.front_left.x = img_sides_corners.corns_cam_right_x(1);
    right_cam_anchors.front_right.x = img_sides_corners.corns_cam_right_x(7);

    right_cam_anchors.back_left.y = img_sides_corners.corns_cam_right_y(3);
    right_cam_anchors.back_right.y = img_sides_corners.corns_cam_right_y(5);
    right_cam_anchors.front_left.y = img_sides_corners.corns_cam_right_y(1);
    right_cam_anchors.front_right.y = img_sides_corners.corns_cam_right_y(7);

    right_cam_anchors.back_left.z_unit = img_sides_corners.corns_cam_right_y(3) - img_sides_corners.corns_cam_right_y(4);
    right_cam_anchors.back_right.z_unit = img_sides_corners.corns_cam_right_y(5) - img_sides_corners.corns_cam_right_y(6);
    right_cam_anchors.front_left.z_unit = img_sides_corners.corns_cam_right_y(1) - img_sides_corners.corns_cam_right_y(2);
    right_cam_anchors.front_right.z_unit = img_sides_corners.corns_cam_right_y(7) - img_sides_corners.corns_cam_right_y(8);

    right_cam_anchors.back_left.grid_x = 4;
    right_cam_anchors.back_right.grid_x = 24;
    right_cam_anchors.front_left.grid_x = 4;
    right_cam_anchors.front_right.grid_x = 24;

    right_cam_anchors.back_left.grid_y = 2;
    right_cam_anchors.back_right.grid_y = 2;
    right_cam_anchors.front_left.grid_y = 22;
    right_cam_anchors.front_right.grid_y = 22;

    % ----- Back camera ------

    back_cam_anchors.back_left.x = img_sides_corners.corns_cam_back_x(5);
    back_cam_anchors.back_right.x = img_sides_corners.corns_cam_back_x(7);
    back_cam_anchors.front_left.x = img_sides_corners.corns_cam_back_x(3);
    back_cam_anchors.front_right.x = img_sides_corners.corns_cam_back_x(1);

    back_cam_anchors.back_left.y = img_sides_corners.corns_cam_back_y(5);
    back_cam_anchors.back_right.y = img_sides_corners.corns_cam_back_y(7);
    back_cam_anchors.front_left.y = img_sides_corners.corns_cam_back_y(3);
    back_cam_anchors.front_right.y = img_sides_corners.corns_cam_back_y(1);

    back_cam_anchors.back_left.z_unit = img_sides_corners.corns_cam_back_y(5) - img_sides_corners.corns_cam_back_y(6);
    back_cam_anchors.back_right.z_unit = img_sides_corners.corns_cam_back_y(7) - img_sides_corners.corns_cam_back_y(8);
    back_cam_anchors.front_left.z_unit = img_sides_corners.corns_cam_back_y(3) - img_sides_corners.corns_cam_back_y(4);
    back_cam_anchors.front_right.z_unit = img_sides_corners.corns_cam_back_y(1) - img_sides_corners.corns_cam_back_y(2);

    back_cam_anchors.back_left.grid_x = 4;
    back_cam_anchors.back_right.grid_x = 20;
    back_cam_anchors.front_left.grid_x = 4;
    back_cam_anchors.front_right.grid_x = 20;

    back_cam_anchors.back_left.grid_y = 0;
    back_cam_anchors.back_right.grid_y = 0;
    back_cam_anchors.front_left.grid_y = 22;
    back_cam_anchors.front_right.grid_y = 22;

end

function res_img = top_image_geometrical_transformation(img_tform,img)

    global cam_width cam_height
    global top_img_size top_img_grid_resolution

    % Stright the image
    outputView = imref2d(size(img));
    [stright_img_not_cropped,~] = imwarp(img,img_tform,'OutputView',outputView);
    
    center_x = cam_width/2;
    center_y = cam_height/2;

    % Cropping the image
    res_img = stright_img_not_cropped(center_y - top_img_size/2 + 1 : center_y + top_img_size/2, ...
                                      center_x - top_img_size/2 + 1: center_x + top_img_size/2, :);
end

function res_img = side_image_geometrical_transformation(img_tform,img)

    % Stright the image
    outputView = imref2d(size(img));
    [res_img,~] = imwarp(img,img_tform,'OutputView',outputView); 
end

%% Binary map masks

function [left_binary_mask, right_binary_mask, back_binary_mask] = generate_sides_binary_mask()

    global cam_height cam_width

    img_sides_mask_coordinates = load('img_sides_masks.mat');
    side_cam_names = ["left","right","back"];

    for i = 1:3 % For "left","right","back"
        side_cam_name = side_cam_names(i);

        switch side_cam_name
            case "left"
                cam_mask_x = img_sides_mask_coordinates.cam_left_mask_x;
                cam_mask_y = img_sides_mask_coordinates.cam_left_mask_y;
            case "right"
                cam_mask_x = img_sides_mask_coordinates.cam_right_mask_x;
                cam_mask_y = img_sides_mask_coordinates.cam_right_mask_y;
            case "back"
                cam_mask_x = img_sides_mask_coordinates.cam_back_mask_x;
                cam_mask_y = img_sides_mask_coordinates.cam_back_mask_y;
        end

        % Fill 
        mask = poly2mask(cam_mask_x,cam_mask_y,cam_height,cam_width);

        switch side_cam_name
            case "left"
                left_binary_mask = mask;
            case "right"
                right_binary_mask = mask;
            case "back"
                back_binary_mask = mask;
        end


    end


end

%% 3D cube function

function is_place_free = check_if_cube_coordinates_occupied(x,y,z,width_x,height_y)
    % The function check if there is a cube in the wanted coordinate (x,y,z)
    % Cubes values:
    %    1 - Yellow
    %    2 - White
    %    3 - Red
    %    4 - Blue
    %    5 - Black

    global game_occupied_matrix % board game
    
    % Get the value in the wanted coordinate (x,y,z) from the 3D cube (board game)
    cube_value_on_board = game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1);
    
    % Check if there are values different tan zero in the cube area (means 
    % there is a cube in this location already).
    cube_value = sum(cube_value_on_board(:));
    
    % Return if there is a cube in the wanted coordinate (x,y,z)
    if cube_value == 0
        is_place_free = true;
    else
        is_place_free = false;
    end        
    
end

%{
function z_coordinate = estimate_z_coord_from_occupied_matrix_by_xy(x,y,width_x,height_y)
    % The function estimate the z coordinate of a cube by its x,y value
    % using the game occupied matrix
    
    global game_occupied_matrix % board game
    
    % Take the cube slice in the wanted x,y for all the z dimentation
    slice_in_xy = game_occupied_matrix(y+1:y+height_y, x+1:x+width_x, :);
    
    global grid_size
    
    % Check if the slice is empty (there are no cubes in those x,y for all
    % z dimentation)
    if sum(slice_in_xy(:)) == 0
        z_coordinate = 0; % return the currect in zero base
    % Else, run on all the z dimentation from the top of the matrix to find
    % the first coordinate there is a cube in it 
    else
        for i=grid_size:-1:1
            z_slice = slice_in_xy(:, :, i);
            if  sum(z_slice(:)) ~= 0
                break;
            end
        end
        z_coordinate = i; % return the currect in zero base
    end

end
%}

function insert_cube_to_game_occupied_matrix(x,y,z,width_x,height_y, cube_color_str)
    % The function enter a cube to the board game.
    % Cubes values:
    %    1 - Yellow
    %    2 - White
    %    3 - Red
    %    4 - Blue
    %    5 - Black
    
    global game_occupied_matrix % board game
    
    % Convert the cube's color from str to number
    cube_color_num = color_str_to_color_num(cube_color_str);
    
    % Set the cube's values in the 3D game board to be the cube's color num in the wanted coordinate (x,y,z)
    game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1) = cube_color_num .* ones([height_y width_x 1]);
    
end

function remove_cube_from_game_occupied_matrix(x,y,z,width_x,height_y)
    % The function remove a cube from the board game
    
    global game_occupied_matrix % board game
    
    % Set the bouad value (the 3D cube) to be zeros in the wanted coordinate (x,y,z)
    game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1) = zeros([height_y width_x 1]);
    
end

function cube_status_add_or_sub = check_for_addition_or_subtraction_of_cube(x,y,z,width_x,height_y)
    % The function gets the cube's coordinate (x,y,z,width_x,height_y).
    % The function determines if the cube was added to the game or removed
    % from it. 
    % Its return 1 in case of addition, -1 in case of substraction and 0 if
    % its non of them
    
    global game_occupied_matrix % board game
    global grid_size

    if x>=0 && x+width_x<= grid_size-1 && y>=0 && y+height_y<= grid_size-1 && z>=0 && z<=grid_size-1
    
        % Get the value in the wanted coordinate (x,y,z) from the 3D cube (board game)
        cube_value_on_board = game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1);
        
            % Return if there is a cube in the wanted coordinate (x,y,z)
        % Check the amount of zeros in the cube area to see if the area was unoccupied
        if sum(cube_value_on_board(:)) == 0 
            cube_status_add_or_sub = 1; % the cube was added
        
        % Check if the values in the cube area are the same
        else
            cube_init_value = cube_value_on_board(1,1); % Check The initiate value from the cube
            cube_status_add_or_sub = -1; % the cube was substracted
            for width_index = 1:width_x
                for height_index = 1:height_y
                    if cube_init_value ~= cube_value_on_board(height_index,width_index)
                        cube_status_add_or_sub = 0; % not clear
                        break;
                    end
                end
            end
        end  
    else
        disp(["Coordinates out of board",x,y,width_x,height_y,z]);
        cube_status_add_or_sub = 0;
    end

end

function color_num = color_str_to_color_num(color_str)
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

function color_str = color_num_to_color_str(color_num)
    % The function convert from color_num to color_str
    % The color values:
    %    1 - Yellow
    %    2 - White
    %    3 - Red
    %    4 - Blue
    %    5 - Black
    
    if color_num == 0
        color_str = "Empty";
    elseif color_num == 1
        color_str = "yellow";
    elseif color_num == 2
        color_str = "white";
    elseif color_num == 3
        color_str = "red";
    elseif color_num == 4
        color_str = "blue";
    else
        color_str = "black";
    end
end

function highest_z = get_highest_occupied_z_in_coordinates(x, y, width, height)

    % The function gets coordinates of [x,y,w,h] and return the z height of
    % the highest cube in those coordinates
    % 0 = no cubes, 1 = one floor occuptied, 2 = two floors occupied

    global game_occupied_matrix % board game
    global grid_size

    above_below_cube_column = game_occupied_matrix(y+1:y+height, x+1:x+width ,:);

    if sum(above_below_cube_column(:)) == 0
        highest_z = 0;
    else
        for check_z = grid_size-1:-1:0
            check_cube = game_occupied_matrix(y+1:y+height, x+1:x+width ,check_z+1);
            if sum(check_cube(:)) ~= 0
                break;
            end
        end
        highest_z = check_z+1;
    end
end

function highest_z = get_highest_occupied_z_in_game_board()

    % The function gets coordinates of [x,y,w,h] and return the z height of
    % the highest cube in those coordinates
    % 0 = no cubes, 1 = one floor occuptied, 2 = two floors occupied

    global game_occupied_matrix % board game
    global grid_size

    if sum(game_occupied_matrix(:)) == 0
        highest_z = 0;
    else
        for check_z = grid_size-1:-1:0
            check_cube = game_occupied_matrix(1:grid_size, 1:grid_size ,check_z+1);
            if sum(check_cube(:)) ~= 0
                break;
            end
        end
        highest_z = check_z+1;
    end
end

function cube_color_str = get_color_of_cube_in_coordinates(x, y, z, width_x, height_y)
    % The function gets coordinates of [x,y,z, w,h] and return the string 
    % color of the cube in those coordinates.
    % If the color codes are not constant/identical, the function returns -1

    global game_occupied_matrix % board game

    % Get the value in the wanted coordinate (x,y,z) from the 3D cube (board game)
    cube_value_on_board = game_occupied_matrix(y+1:y+height_y, x+1:x+width_x ,z+1);

    % Check if all values of cubes are in same color:
    cube_init_value = cube_value_on_board(1,1); % Check The initiate value from the cube
    are_all_cells_in_same_color = true; % init with flag = all in same color
    for width_index = 1:width_x
        for height_index = 1:height_y
            if cube_init_value ~= cube_value_on_board(height_index,width_index)
                are_all_cells_in_same_color = false; % not all in same color
                break;
            end
        end
    end

    if are_all_cells_in_same_color
        cube_color_str = color_num_to_color_str(cube_init_value);
    else
        cube_color_str = "MixedColors";
    end

end

function is_free_los = get_if_free_line_of_sight(x,y,min_z,max_z,width_x,height_y,camera_side)
    % The function gets the cube's coordinate (x,y,z,width_x,height_y)
    % and a camera side (left\right\back)
    % The function determines if there is free line of sight from the
    % camera to the cube
    % Its return 1 in case of free los, and 0 otherwise
    
    global game_occupied_matrix % board game
    global grid_size

    % If the cube is on the camera edge, no need to check volume because
    % los is automaticlly exist
    volume_cube_to_cam_exist = true;
    
    switch camera_side
        case "left"
            if x == 0
                volume_cube_to_cam_exist = false;
            else
                volume_cam_to_cube = game_occupied_matrix(y+1:y+height_y, 1:x ,min_z+1:max_z+1);
            end
         case "right"
            if x == grid_size-1
                volume_cube_to_cam_exist = false;
            else
                volume_cam_to_cube = game_occupied_matrix(y+1:y+height_y, x+width_x+1 : grid_size ,min_z+1:max_z+1);
            end
         case "back"
            if y == 0
                volume_cube_to_cam_exist = false;
            else
                volume_cam_to_cube = game_occupied_matrix(1:y, x+1:x+width_x ,min_z+1:max_z+1);
            end
    end

    if volume_cube_to_cam_exist
        % If found volume
        is_free_los = (sum(volume_cam_to_cube(:)) == 0);
    else
        % If the cube is on the camera edge, no need to check volume because
        % los is automaticlly exist
        is_free_los = true;
    end
end

function [detect_flag, x_ret, y_ret, width_x_ret, height_y_ret] = get_location_for_rest_of_cube(x,y,width_x,height_y, org_cube_color_str)
    % The function detect 
    global grid_size
    
    % initiate detect_flag
    detect_flag = 0;
    
    % Initiate num of possible option for the cube state
    possible_state_num = 0;
    
    % -----------------------------------------------------------------
    % width_x == 1 && height_y == 4
    if width_x == 1 && height_y == 4
        if x-1 >= 0
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x-1, y, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x-1, y, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x-1;
                    y_ret = y;
                    width_x_ret = 2;
                    height_y_ret = 4;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
        if x+1+width_x <= grid_size-1
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x+1, y, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x+1, y, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x;
                    y_ret = y;
                    width_x_ret = 2;
                    height_y_ret = 4;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
    % -----------------------------------------------------------------
    % width_x == 4 && height_y == 1
    elseif width_x == 4 && height_y == 1
        if y-1 >= 0
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x, y-1, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x, y-1, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x;
                    y_ret = y-1;
                    width_x_ret = 4;
                    height_y_ret = 2;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
        if y+1+height_y <= grid_size-1
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x, y+1, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x, y+1, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x;
                    y_ret = y;
                    width_x_ret = 4;
                    height_y_ret = 2;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
    % -----------------------------------------------------------------
    % width_x == 2 && height_y == 2
    elseif width_x == 2 && height_y == 2
        if x-2 >= 0
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x-2, y, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x-2, y, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x-2;
                    y_ret = y;
                    width_x_ret = 4;
                    height_y_ret = 2;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end 
        if y-2 >= 0
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x, y-2, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x, y-2, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x;
                    y_ret = y-2;
                    width_x_ret = 2;
                    height_y_ret = 4;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
        if x+2+width_x <= grid_size-1
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x+2, y, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x+2, y, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x;
                    y_ret = y;
                    width_x_ret = 4;
                    height_y_ret = 2;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
        if y+2+height_y <= grid_size-1
            % Get highest z value in the xy strip
            z = get_highest_occupied_z_in_coordinates(x, y+2, width_x, height_y);
            if z~=0
                cube_color_str = get_color_of_cube_in_coordinates(x, y+2, z-1, width_x, height_y);
                if org_cube_color_str == cube_color_str
                    x_ret = x;
                    y_ret = y;
                    width_x_ret = 2;
                    height_y_ret = 4;
                    detect_flag = 1;
                    possible_state_num = possible_state_num + 1;
                end
            end
        end
    end   
    
    if possible_state_num ~= 1
        x_ret = 0;
        y_ret = 0;
        width_x_ret = 0;
        height_y_ret = 0;
        detect_flag = 0;
    end

end