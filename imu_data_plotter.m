%data = reshape(data, 6, [])';

data(:,3) = data(:,3)+1;

ax = data(:,1);
ay = data(:,2);
az = data(:,3);
gx = data(:,4);
gy = data(:,5);
gz = data(:,6);

figure;
plot(ax,'Color', '#A2142F')
hold on
plot(ay, 'Color', '#FF0000')
plot(az, 'Color', '#D95319')
plot(gx, 'Color', '#0072BD')
plot(gy, 'Color', '#0000FF')
plot(gz, 'Color', '#4DBEEE')
legend('ax', 'ay', 'az', 'gx', 'gy', 'gz')

bias = mean(data, 1)
noise = rms(data, 1)
