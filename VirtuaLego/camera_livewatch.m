function camera_livewatch()
    % Show live watch of selected camera

    global app_state

    if app_state == "Camera live watch"
        app_state = "Camera stop live watch";
        disp(["App state: ",app_state]);
        return
    end

    app_state = "Camera live watch";
    disp(["App state: ",app_state]);

    global cam_top cam_left cam_right cam_back cam_demo

    % Select the live watch camera
    selected_cam_value = input("Select camera (top=1, left=2, right=3, back=4, demo=5) . Selection? ");
    switch selected_cam_value
        case 1
            selected_cam = cam_top;
        case 2
            selected_cam = cam_left;
        case 3
            selected_cam = cam_right;
        case 4
            selected_cam = cam_back;
        case 5
            selected_cam = cam_demo;
    end

     % Start live watch
     livewatch_fig = figure;
     start(selected_cam);
     trigger(selected_cam);

     while true

        loop_img = ycbcr2rgb (getsnapshot(selected_cam));
        imshow(loop_img);

        if app_state ~= "Camera live watch"
            break;
        end

        pause(0.1);
        
     end

     stop(selected_cam);
     close(livewatch_fig);
end