const express = require('express');
const morgan = require('morgan');
const handlebars = require('express-handlebars');
const helpers = require('handlebars-helpers');
const comparison = helpers.comparison();
const Handlebars = require('handlebars');
const MomentHandler = require('handlebars.moment');
MomentHandler.registerHelpers(Handlebars);
const moment = require('moment'); 
const path = require('path');
// const session = require('express-session'); 
const app = express();
const port = 2000;
const route = require('./routes');
const db = require('./config/db'); // [#1]

// Use Image
app.use(express.static(path.join(__dirname, 'public')));

// Connect to db    // [#1]
db.connect();

//
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// HTTP logger
app.use(morgan('tiny'));

// Cấu hình session middleware
// app.use(session({
//     secret: 'your-secret-key', // Đặt khóa bí mật để ký phiên làm việc
//     resave: false, // Không lưu phiên nếu không thay đổi
//     saveUninitialized: true, // Lưu phiên mới ngay cả khi chưa có dữ liệu
//     cookie: { secure: false } // Đặt thành true nếu sử dụng HTTPS
// }));

// Template engine
app.engine('hbs', handlebars.engine({ extname: '.hbs', helpers: comparison }));
app.set('view engine', 'hbs');
app.set('views', path.join(__dirname, 'resources', 'views'));

// Register the helper
// Dùng cho array bắt đầu từ startIndex đến hết
Handlebars.registerHelper('eachFromIndex', function(array, startIndex, options) {
    let result = '';
    for (let i = startIndex; i < array.length; i++) {
        result += options.fn(array[i]);
    }
    return result;
});

// Trả về days (days ago) (vd: days = 30 -> 30 days ago; days = -1 -> tomorrow)
Handlebars.registerHelper('daysAgo', function(days, format) {
    return moment().subtract(days, 'days').format(format);
});

// Routes init
route(app);

app.listen(port, () => {
    console.log(`App listening on port ${port}`);
});
