# SngLib · thư viện tra cứu

Ứng dụng web tĩnh (một file `index.html`) để tra cứu tài liệu học thuật, quản lý kệ sách và xuất trích dẫn APA / CSV.

- Không cần build, không cần server, không có dependency.
- Tra cứu qua API công khai: OpenAlex, Crossref (gọi trực tiếp từ trình duyệt).
- Kệ sách lưu bằng `localStorage` trên máy người dùng.
- Chọn chuẩn trích dẫn **APA, Harvard, MLA hoặc IEEE** (lựa chọn được nhớ lại cho lần sau).
- Xuất danh mục ra CSV, file Word (HTML), **BibTeX** (`.bib`) và **RIS** (`.ris`) để dùng với Zotero, Mendeley, EndNote.
- **Chia sẻ link**: nút "Chia sẻ" sao chép địa chỉ chứa sẵn từ khóa, bộ lọc năm, lọc PDF và tab đang xem, mở link là ra đúng kết quả đó (dạng `#q=...&kt=2&pdf=1&t=0`).
- **Sao lưu Kệ sách**: tải file JSON và nhập lại trên máy khác (chỉ nhập các trường dữ liệu an toàn, bỏ link nguy hiểm, tối đa 5 MB / 3000 bài).
- Giao diện tự đổi sáng/tối theo hệ thống.

## Chạy thử

Mở `index.html` bằng trình duyệt, hoặc chạy server cục bộ:

```bash
python3 -m http.server 8080
# mở http://localhost:8080
```

## Triển khai (GitHub Pages)

Repo đã có sẵn workflow `.github/workflows/pages.yml`. Chỉ cần:

1. Push code lên nhánh `main`.
2. Vào **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Sau vài chục giây, trang chạy tại `https://<user>.github.io/<repo>/`.

## Cấu trúc

```
.
├── index.html                  # ứng dụng chính
├── logo.svg                    # logo
├── site.js                     # ghi lượt truy cập, hiện thông báo / link
├── config.js                   # URL + anon key Supabase
├── admin/index.html            # trang quản trị
├── supabase/schema.sql         # bảng, RLS, hàm thống kê
├── README.md
├── LICENSE
├── .gitignore
├── .nojekyll
└── .github/workflows/pages.yml # tự động deploy
```

## Trang quản trị (`/admin/`)

Trang `admin/index.html` cho phép:

- **Thống kê**: người đang online, lượt xem / người truy cập theo ngày, giờ cao điểm, từ khóa tìm nhiều, nguồn truy cập, thiết bị, trình duyệt, ngôn ngữ, múi giờ.
- **Thông báo**: tạo / sửa / bật tắt / hẹn giờ hiển thị / xóa. Hiện thành banner đầu trang chính, khách có thể đóng.
- **Liên kết**: quản lý các link hiện ở cuối trang chính.

Dữ liệu lưu trên [Supabase](https://supabase.com) (miễn phí), trang vẫn là web tĩnh nên deploy GitHub Pages bình thường.

### Cài đặt

1. Tạo dự án Supabase → **SQL Editor** → dán toàn bộ `supabase/schema.sql` → Run.
2. **Authentication → Users → Add user** (email + mật khẩu, tick *Auto confirm*). Sau đó tắt *Allow new users to sign up*.
3. Cấp quyền admin cho tài khoản đó:
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'ban@example.com';
   ```
4. **Project Settings → API**: copy *Project URL* và *anon / publishable key* vào `config.js`.
5. Commit, push. Vào `https://<user>.github.io/<repo>/admin/` để đăng nhập.

### Bảo mật & quyền riêng tư

- Khóa trong `config.js` là khóa công khai. Quyền thật nằm ở Row Level Security: khách chỉ ghi được lượt truy cập và đọc thông báo / link đang bật; mọi thao tác khác cần tài khoản có trong bảng `admins`.
- **Không** dán `service_role` key vào repo.
- Không lưu IP. Chỉ lưu ID ngẫu nhiên trong trình duyệt, thiết bị, trình duyệt, ngôn ngữ, múi giờ và từ khóa tìm. Tôn trọng Do Not Track, bỏ qua bot, localhost, và lượt truy cập của admin đã đăng nhập.
- Nếu chưa điền `config.js`, trang chính vẫn chạy bình thường, chỉ không có thống kê / thông báo.

## Giấy phép

MIT
