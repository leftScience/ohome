package service

import (
	"errors"
	"ohome/model"
	"ohome/service/dto"
	"strings"
	"time"

	"gorm.io/gorm"
)

type TodoService struct {
	BaseService
}

func (s *TodoService) GetList(listDTO *dto.TodoListDTO, ownerUserID uint) ([]model.TodoItem, int64, error) {
	if ownerUserID == 0 {
		return nil, 0, errors.New("用户信息不存在")
	}
	return todoDao.GetList(ownerUserID, listDTO)
}

func (s *TodoService) Create(createDTO *dto.TodoItemCreateDTO, loginUser model.LoginUser) (model.TodoItem, error) {
	if loginUser.ID == 0 {
		return model.TodoItem{}, errors.New("用户信息不存在")
	}

	title, err := normalizeTodoTitle(createDTO.Title)
	if err != nil {
		return model.TodoItem{}, err
	}

	item := model.TodoItem{
		OwnerUserID: loginUser.ID,
		CreatedBy:   loginUser.ID,
		UpdatedBy:   loginUser.ID,
		Title:       title,
		SortOrder:   nextTodoSortOrder(loginUser.ID),
		Completed:   false,
	}
	if err := todoDao.Create(&item); err != nil {
		return model.TodoItem{}, err
	}
	return item, nil
}

func (s *TodoService) Update(updateDTO *dto.TodoItemUpdateDTO, loginUser model.LoginUser) (model.TodoItem, error) {
	item, err := s.getOwnedTodoItem(updateDTO.ID, loginUser.ID)
	if err != nil {
		return model.TodoItem{}, err
	}

	title, err := normalizeTodoTitle(updateDTO.Title)
	if err != nil {
		return model.TodoItem{}, err
	}

	item.Title = title
	item.UpdatedBy = loginUser.ID
	if err := todoDao.Save(&item); err != nil {
		return model.TodoItem{}, err
	}
	return item, nil
}

func (s *TodoService) UpdateStatus(statusDTO *dto.TodoItemStatusDTO, loginUser model.LoginUser) (model.TodoItem, error) {
	if statusDTO.Completed == nil {
		return model.TodoItem{}, errors.New("完成状态不能为空")
	}

	item, err := s.getOwnedTodoItem(statusDTO.ID, loginUser.ID)
	if err != nil {
		return model.TodoItem{}, err
	}

	completed := *statusDTO.Completed
	item.Completed = completed
	item.UpdatedBy = loginUser.ID
	if completed {
		if item.CompletedAt == nil {
			now := time.Now()
			item.CompletedAt = &now
		}
	} else {
		item.CompletedAt = nil
	}

	if err := todoDao.Save(&item); err != nil {
		return model.TodoItem{}, err
	}
	return item, nil
}

func (s *TodoService) Delete(idDTO *dto.CommonIDDTO, loginUser model.LoginUser) error {
	item, err := s.getOwnedTodoItem(idDTO.ID, loginUser.ID)
	if err != nil {
		return err
	}
	return todoDao.Delete(item.ID)
}

func (s *TodoService) Reorder(reorderDTO *dto.TodoReorderDTO, loginUser model.LoginUser) error {
	if loginUser.ID == 0 {
		return errors.New("用户信息不存在")
	}

	ids, err := normalizeTodoReorderIDs(reorderDTO.IDs)
	if err != nil {
		return err
	}

	pendingTotal, err := todoDao.CountPendingByOwner(loginUser.ID)
	if err != nil {
		return err
	}
	if pendingTotal == 0 {
		return errors.New("暂无可排序待办")
	}
	if int64(len(ids)) != pendingTotal {
		return errors.New("排序数据已过期，请刷新后重试")
	}

	matchedCount, err := todoDao.CountPendingByOwnerAndIDs(loginUser.ID, ids)
	if err != nil {
		return err
	}
	if matchedCount != pendingTotal {
		return errors.New("排序数据包含无效待办")
	}

	return todoDao.ReorderPending(loginUser.ID, loginUser.ID, ids)
}

func (s *TodoService) getOwnedTodoItem(id, ownerUserID uint) (model.TodoItem, error) {
	if ownerUserID == 0 {
		return model.TodoItem{}, errors.New("用户信息不存在")
	}
	if id == 0 {
		return model.TodoItem{}, errors.New("待办ID不能为空")
	}

	item, err := todoDao.GetByOwnerAndID(id, ownerUserID)
	if err == nil {
		return item, nil
	}
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.TodoItem{}, errors.New("待办不存在")
	}
	return model.TodoItem{}, err
}

func normalizeTodoTitle(value string) (string, error) {
	title := strings.TrimSpace(value)
	if title == "" {
		return "", errors.New("待办标题不能为空")
	}
	return title, nil
}

func normalizeTodoReorderIDs(ids []uint) ([]uint, error) {
	if len(ids) == 0 {
		return nil, errors.New("待办排序不能为空")
	}

	unique := make(map[uint]struct{}, len(ids))
	result := make([]uint, 0, len(ids))
	for _, id := range ids {
		if id == 0 {
			return nil, errors.New("待办ID不能为空")
		}
		if _, exists := unique[id]; exists {
			return nil, errors.New("待办排序存在重复项")
		}
		unique[id] = struct{}{}
		result = append(result, id)
	}
	return result, nil
}

func nextTodoSortOrder(ownerUserID uint) int64 {
	minSortOrder, err := todoDao.GetPendingMinSortOrder(ownerUserID)
	if err != nil {
		return 1024
	}
	if minSortOrder == 0 {
		return -1024
	}
	return minSortOrder - 1024
}
