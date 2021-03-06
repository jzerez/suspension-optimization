classdef Knuckle < handle
    properties
        pca_node;   % Passive Control Arm (Not connected to shock)
        aca_node;   % Active Control Arm (connected to shock)
        toe_node;   % Point that controls toe
        axis;       % Kingpin axis from pca to aca
        toe_radius; % Radial distance of toe point from kingpin axis
        toe_height; % Axial distance of toe point from aca along axis
        toe_center; % Point along the kingpin axis where toe rotates about
        a_arm_dist; % Dist from pca to aca 
        toe_plane;  % Plane that the toe point rotates in
        action_plane; % Plane that includes pca, aca, and toe
        
        wheel;      % Wheel object
        wheel_center_offset1;   % location of wheel center relative to aca using knuckle coordinates
        wheel_center_offset2;   % location of wheel axis point relative to aca using knuckle coordinates
        
        % Knuckle Coordinates:
        % 1st dimension: Along kingpin axis
        % 2nd dimension: Normal to axis, in the action plane
        % 3rd dimension: Normal to action plane
        
    end
    
    methods
        function self = Knuckle(pca_node, aca_node, toe_node, wheel)
            self.pca_node = pca_node;
            self.aca_node = aca_node;
            self.toe_node = toe_node;
            
            self.wheel = wheel;
            self.update();
        end
        
        function res = valid_length(self)
            dist = norm(self.pca_node.location - self.aca_node.location);
            res = (abs(dist - self.a_arm_dist) < 1e-8);
        end
        
        function theta = calc_signed_steering_angle_raw(self)
            toe_lever = unit(self.toe_node.location - self.toe_center);
            forward_v = unit(self.toe_plane.project_into_plane([0;0;1] + self.toe_center) - self.toe_center);
            unsigned_toe_offset = acosd(dot(toe_lever, forward_v));
            sign = -dot(unit(cross(self.toe_center+forward_v, self.toe_center+toe_lever)), self.axis);
            if sign > 0
                direction = 1;
            else
                direction = -1;
            end
            theta = unsigned_toe_offset * direction;
        end

        function update_toe_plane(self)
            axis = self.pca_node.location - self.aca_node.location;
            self.axis = unit(axis);
            self.toe_center = self.toe_height * self.axis + self.aca_node.location;
            self.toe_plane = Plane(self.toe_center, self.axis);
        end
        
        function update_action_plane(self)
            % Updates the action plane and the wheel orientation/position.
            
            % update toe plane
            self.axis = unit(self.pca_node.location - self.aca_node.location);
            self.toe_center = self.toe_height * self.axis + self.aca_node.location;
            self.toe_plane = Plane(self.toe_center, self.axis);
            
            % update action plane
            self.action_plane = Plane(self.pca_node.location, self.aca_node.location, self.toe_node.location);
            
            % Define unit vectors for knuckle coordinates (M)
            toe_to_aca = (self.toe_node.location - self.aca_node.location);
            axis_normal = unit(toe_to_aca - (self.toe_height*self.axis));
            plane_normal = unit(cross(self.axis, axis_normal));
            if plane_normal(1) > 0
                plane_normal = -plane_normal;
            end
            M = [self.axis, axis_normal, plane_normal];
            
            % Recalculate wheel center, axis, and axis point using Knuckle
            % coordinates (M)
            self.wheel.center = sum(self.wheel_center_offset1' .* M, 2) + self.aca_node.location;
            self.wheel.axis_point = sum(self.wheel_center_offset2' .* M, 2) + self.aca_node.location;
            self.wheel.axis = self.wheel.axis_point - self.wheel.center;
            self.wheel.plane = Plane(self.wheel.center, self.wheel.axis);
            self.wheel.update();
        end
        
        function update(self)
            self.wheel.initialize(self.wheel.static_center);
            self.axis = unit(self.pca_node.location - self.aca_node.location);
            
            toe_to_aca = (self.toe_node.location - self.aca_node.location);
            self.toe_height = dot(toe_to_aca, self.axis);
            self.toe_center = self.toe_height * self.axis + self.aca_node.location;
            axis_normal = toe_to_aca - (self.toe_height*self.axis);
            self.toe_radius = norm(axis_normal);
            plane_normal = cross(unit(axis_normal), self.axis);
            
            if plane_normal(1) > 0
                plane_normal = -plane_normal;
            end
            
            self.a_arm_dist = norm(self.pca_node.location - self.aca_node.location);
            
            wheel_center_v1 = self.wheel.center - self.aca_node.location;
            wheel_center_v2 = self.wheel.axis_point - self.aca_node.location;
            self.wheel_center_offset1 = [dot(wheel_center_v1, self.axis);...
                                         dot(wheel_center_v1, unit(axis_normal));...
                                         dot(wheel_center_v1, plane_normal)];
            
            self.wheel_center_offset2 = [dot(wheel_center_v2, self.axis);...
                                         dot(wheel_center_v2, unit(axis_normal));...
                                         dot(wheel_center_v2, plane_normal)];
            
            self.update_toe_plane();
            self.update_action_plane();
        end
        
        function [camber, toe] = calc_camber_and_toe(self)
            n = self.wheel.plane.normal;
            x = [1;0;0];
            y = [0;1;0];
            z = [0;0;1];
            toe_vec = unit(x*(-dot(n, z) / dot(n, x)) + z);
            camber_vec = unit(x*(-dot(n, y) / dot(n, x)) + y);
            if toe_vec(1) < 0
                toe_direction = 1;
            else
                toe_direction = -1;
            end
            if camber_vec(1) < 0
                camber_direction = -1;
            else
                camber_direction = 1;
            end
            toe = acosd(dot(toe_vec, z)) * toe_direction;
            camber = acosd(dot(camber_vec, y)) * camber_direction;
        end
        
    end
end