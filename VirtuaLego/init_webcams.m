function init_webcams()
    % Init webcams objects
    global cam_top cam_left cam_right cam_back cam_demo

    global app_state
    app_state = "Init cameras";
    disp(["App state: ",app_state]);

    delete(imaqfind)

    global isDemo

    if ~isDemo
        % Get saved indexes from .mat file
        cam_idx_order = load('cam_config.mat');
        top_cam_idx = cam_idx_order.top_cam_idx;
        left_cam_idx = cam_idx_order.left_cam_idx;
        right_cam_idx = cam_idx_order.right_cam_idx;
        back_cam_idx = cam_idx_order.back_cam_idx;
    
        cam_top = videoinput('winvideo',num2str(top_cam_idx),'YUY2_640x480');
        cam_left = videoinput('winvideo',num2str(left_cam_idx),'YUY2_640x480');
        cam_right = videoinput('winvideo',num2str(right_cam_idx),'YUY2_640x480');
        cam_back = videoinput('winvideo',num2str(back_cam_idx),'YUY2_640x480');

        triggerconfig(cam_top, 'manual');
        triggerconfig(cam_left, 'manual');
        triggerconfig(cam_right, 'manual');
        triggerconfig(cam_back, 'manual');

        cam_top.Timeout = 10;
        cam_left.Timeout = 10;
        cam_right.Timeout = 10;
        cam_back.Timeout = 10;
        

        cam_top.FramesPerTrigger = inf;
        cam_left.FramesPerTrigger = inf; 
        cam_right.FramesPerTrigger = inf; 
        cam_back.FramesPerTrigger = inf; 

    else
        cam_demo = videoinput('winvideo','1');

        triggerconfig(cam_demo, 'manual');
    end
end