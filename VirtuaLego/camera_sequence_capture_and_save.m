function camera_sequence_capture_and_save()
    % Show live watch of selected camera

    global app_state

    if app_state == "Camera seqenuce capture and save"
        app_state = "Camera stop seqenuce capture and save";
        disp(["App state: ",app_state]);
        return
    end

    app_state = "Camera seqenuce capture and save";
    disp(["App state: ",app_state]);

    global cam_top cam_left cam_right cam_back cam_demo

    global sequence_capture_and_save_seq_counter

    % Select the live watch camera
    selected_cam_value = 1; %input("Select camera (top=1, left=2, right=3, back=4, demo=5) . Selection? ");
    switch selected_cam_value
        case 1
            selected_cam = cam_top;
            selected_cam_name = "cam_top";
        case 2
            selected_cam = cam_left;
            selected_cam_name = "cam_left";
        case 3
            selected_cam = cam_right;
            selected_cam_name = "cam_right";
        case 4
            selected_cam = cam_back;
            selected_cam_name = "cam_back";
        case 5
            selected_cam = cam_demo;
            selected_cam_name = "cam_demo";
    end

     % Start live watch
     livewatch_fig = figure;
     start(selected_cam);
     trigger(selected_cam);

     sequence_counter = 1;
     while true

        loop_img = ycbcr2rgb (getsnapshot(selected_cam));
        imshow(loop_img);
        file_name = selected_cam_name+"_"+num2str(sequence_counter)+".bmp";
        img_path = fullfile("DemoImages","SequenceCatputeAndSave_"+num2str(sequence_capture_and_save_seq_counter),file_name);
        imwrite(loop_img,img_path);
        disp("saved: "+img_path);
        sequence_counter = sequence_counter+1;

        if app_state ~= "Camera seqenuce capture and save"
            sequence_capture_and_save_seq_counter = sequence_capture_and_save_seq_counter+1;
            break;
        end

        pause(0.02);
        
     end

     stop(selected_cam);
     close(livewatch_fig);
end